using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.Model.Configuration;

namespace RotoMonsterTwitter.API.Middleware;

public class ApiKeyMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ApiKeyOptions _options;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<ApiKeyMiddleware> _logger;

    public ApiKeyMiddleware(RequestDelegate next, IOptions<ApiKeyOptions> options,
        IWebHostEnvironment env, ILogger<ApiKeyMiddleware> logger)
    {
        _next = next;
        _options = options.Value;
        _env = env;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? "";

        var isAnonymous = _options.AnonymousPaths.Any(p =>
            path.StartsWith(p, StringComparison.OrdinalIgnoreCase));

        if (isAnonymous)
        {
            await _next(context);
            return;
        }

        // No keys configured: allowed in Development so local work isn't
        // blocked, refused anywhere else rather than silently running open.
        if (_options.Clients.Count == 0)
        {
            if (_env.IsDevelopment())
            {
                await _next(context);
                return;
            }

            _logger.LogError(
                "No API keys are configured, so every request is being refused. "
                + "Populate the ApiKeys:Clients section.");

            await Deny(context, "API is not configured for access.");
            return;
        }

        var supplied = context.Request.Headers[_options.HeaderName].FirstOrDefault();

        if (string.IsNullOrWhiteSpace(supplied))
        {
            await Deny(context, $"Missing {_options.HeaderName} header.");
            return;
        }

        var client = Match(supplied);

        if (client == null)
        {
            _logger.LogWarning("Rejected request to {Path} from {Ip}: bad API key.",
                path, context.Connection.RemoteIpAddress);

            await Deny(context, "Invalid API key.");
            return;
        }

        context.Items["ApiClient"] = client;

        await _next(context);
    }

    /// <summary>
    /// Fixed-time comparison, so response timing can't be used to guess a key
    /// one character at a time.
    /// </summary>
    private string? Match(string supplied)
    {
        var suppliedBytes = Encoding.UTF8.GetBytes(supplied);

        foreach (var (name, key) in _options.Clients)
        {
            if (string.IsNullOrWhiteSpace(key)) continue;

            var keyBytes = Encoding.UTF8.GetBytes(key);

            if (keyBytes.Length == suppliedBytes.Length &&
                CryptographicOperations.FixedTimeEquals(keyBytes, suppliedBytes))
            {
                return name;
            }
        }

        return null;
    }

    private static async Task Deny(HttpContext context, string message)
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(
            $"{{\"success\":false,\"errorMessage\":\"{message}\"}}");
    }
}
