#!/usr/bin/env bash
#
# RotoMonsterTwitter - adds X posting + API key auth + a lists controller.
#
# Writes complete files rather than patching, so it can be run on its own and
# re-run safely. Replaces rmt-poster.sh, rmt-scheduler.sh and rmt-auth.sh.
#
# No in-app scheduler: Ken is triggering ingest from his own monitoring apps.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

mkdir -p RotoMonsterTwitter.API/Middleware

echo "Writing configuration..."

cat > RotoMonsterTwitter.Model/Configuration/TwitterPostOptions.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Configuration;

/// <summary>
/// OAuth 1.0a credentials for posting to X. These come from an X developer
/// app - twitterapi.io is read-only and cannot post.
/// </summary>
public class TwitterPostOptions
{
    public const string SectionName = "TwitterPost";

    public string ConsumerKey { get; set; } = "";
    public string ConsumerSecret { get; set; } = "";
    public string AccessToken { get; set; } = "";
    public string AccessTokenSecret { get; set; } = "";

    public string PostUrl { get; set; } = "https://api.twitter.com/2/tweets";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ConsumerKey) &&
        !string.IsNullOrWhiteSpace(ConsumerSecret) &&
        !string.IsNullOrWhiteSpace(AccessToken) &&
        !string.IsNullOrWhiteSpace(AccessTokenSecret);
}
CSEOF

cat > RotoMonsterTwitter.Model/Configuration/ApiKeyOptions.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Configuration;

public class ApiKeyOptions
{
    public const string SectionName = "ApiKeys";

    public string HeaderName { get; set; } = "X-API-Key";

    /// <summary>
    /// Client name -> key. Named so logs show who called, and so one client's
    /// key can be revoked without disturbing the others.
    /// </summary>
    public Dictionary<string, string> Clients { get; set; } = new();

    /// <summary>Paths that skip the check. Health stays open for monitoring.</summary>
    public List<string> AnonymousPaths { get; set; } = new() { "/health" };
}
CSEOF

echo "Writing request and result..."

cat > RotoMonsterTwitter.Model/Requests/PostTweetRequest.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Requests;

public class PostTweetRequest
{
    public string Text { get; set; } = "";
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/PostTweetResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class PostTweetResult : BaseResult
{
    public string? TweetId { get; set; }
    public string? Text { get; set; }
}
CSEOF

echo "Writing poster service..."

cat > RotoMonsterTwitter.Model/Services/ITwitterPosterService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITwitterPosterService
{
    Task<PostTweetResult> PostTweetAsync(string text, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TwitterPosterService.cs <<'CSEOF'
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Posts to X API v2 using OAuth 1.0a user-context signing. Ported from Ken's
/// SharedCS TwitterPoster, made async, with a fixed nonce generator and the
/// API's error body surfaced instead of swallowed.
/// </summary>
public class TwitterPosterService : ITwitterPosterService
{
    private static readonly DateTime UnixEpoch =
        new(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private readonly HttpClient _http;
    private readonly TwitterPostOptions _options;

    public TwitterPosterService(HttpClient http, IOptions<TwitterPostOptions> options)
    {
        _http = http;
        _options = options.Value;
    }

    public async Task<PostTweetResult> PostTweetAsync(
        string text, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return Fail("Tweet text is required.");
        }

        if (!_options.IsConfigured)
        {
            return Fail("X API credentials are not configured. "
                + "Set the TwitterPost section (ConsumerKey, ConsumerSecret, "
                + "AccessToken, AccessTokenSecret).");
        }

        try
        {
            var request = BuildRequest(text);
            var response = await _http.SendAsync(request, ct);
            var body = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                return Fail($"X API returned {(int)response.StatusCode}: {Trim(body)}");
            }

            var data = JObject.Parse(body)["data"];

            return new PostTweetResult
            {
                TweetId = data?["id"]?.ToString(),
                Text = data?["text"]?.ToString() ?? text
            };
        }
        catch (Exception ex)
        {
            return Fail(ex.Message);
        }
    }

    private HttpRequestMessage BuildRequest(string text)
    {
        var oauth = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["oauth_consumer_key"] = _options.ConsumerKey,
            ["oauth_nonce"] = Guid.NewGuid().ToString("N"),
            ["oauth_signature_method"] = "HMAC-SHA1",
            ["oauth_timestamp"] = ((long)(DateTime.UtcNow - UnixEpoch).TotalSeconds)
                .ToString(),
            ["oauth_token"] = _options.AccessToken,
            ["oauth_version"] = "1.0"
        };

        // The JSON body is not part of the signature base for v2, since the
        // body is not form-encoded. Only the oauth parameters are signed.
        var parameterString = string.Join("&",
            oauth.Select(kv => $"{Escape(kv.Key)}={Escape(kv.Value)}"));

        var signatureBase = string.Concat(
            "POST&", Escape(_options.PostUrl), "&", Escape(parameterString));

        var signingKey = string.Concat(
            Escape(_options.ConsumerSecret), "&", Escape(_options.AccessTokenSecret));

        using var hmac = new HMACSHA1(Encoding.UTF8.GetBytes(signingKey));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(signatureBase));

        oauth["oauth_signature"] = Convert.ToBase64String(hash);

        var header = string.Join(", ",
            oauth.Select(kv => $"{Escape(kv.Key)}=\"{Escape(kv.Value)}\""));

        var payload = new JObject { ["text"] = text }
            .ToString(Newtonsoft.Json.Formatting.None);

        var request = new HttpRequestMessage(HttpMethod.Post, _options.PostUrl)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        };

        request.Headers.Authorization = new AuthenticationHeaderValue("OAuth", header);

        return request;
    }

    /// <summary>
    /// RFC 3986 percent-encoding. Uri.EscapeDataString has varied across .NET
    /// versions on whether it escapes ! ' ( ) *, and an OAuth signature breaks
    /// if the client and server disagree by a single character.
    /// </summary>
    private static string Escape(string value)
    {
        const string unreserved =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

        var builder = new StringBuilder(value.Length * 2);

        foreach (var b in Encoding.UTF8.GetBytes(value))
        {
            var c = (char)b;
            if (unreserved.IndexOf(c) >= 0)
            {
                builder.Append(c);
            }
            else
            {
                builder.Append('%').Append(b.ToString("X2"));
            }
        }

        return builder.ToString();
    }

    private static PostTweetResult Fail(string message)
        => new() { Success = false, ErrorMessage = message };

    private static string Trim(string value)
        => value.Length > 400 ? value[..400] + "..." : value;
}
CSEOF

echo "Writing API key middleware..."

cat > RotoMonsterTwitter.API/Middleware/ApiKeyMiddleware.cs <<'CSEOF'
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
CSEOF

echo "Writing controllers..."

cat > RotoMonsterTwitter.API/Controllers/TweetsController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/tweets")]
public class TweetsController : ControllerBase
{
    private readonly ITweetService _tweets;
    private readonly ITweetIngestService _ingest;
    private readonly ITwitterPosterService _poster;

    public TweetsController(ITweetService tweets, ITweetIngestService ingest,
        ITwitterPosterService poster)
    {
        _tweets = tweets;
        _ingest = ingest;
        _poster = poster;
    }

    [HttpPost("GetTweets")]
    public async Task<IActionResult> GetTweets(
        [FromBody] GetTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.GetTweetsAsync(request, ct));

    [HttpGet("ReadTweet/{tweetId}")]
    public async Task<IActionResult> ReadTweet(string tweetId, CancellationToken ct)
        => Ok(await _tweets.ReadTweetAsync(tweetId, ct));

    [HttpGet("ReadTweetList/{listId:long}")]
    public async Task<IActionResult> ReadTweetList(long listId,
        [FromQuery] int maxResults = 100, CancellationToken ct = default)
        => Ok(await _tweets.ReadTweetListAsync(listId, maxResults, ct));

    [HttpPost("DeleteTweets")]
    public async Task<IActionResult> DeleteTweets(
        [FromBody] DeleteTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.DeleteTweetsAsync(request, ct));

    [HttpPost("PostTweet")]
    public async Task<IActionResult> PostTweet(
        [FromBody] PostTweetRequest request, CancellationToken ct)
        => Ok(await _poster.PostTweetAsync(request.Text, ct));

    /// <summary>Pull new tweets for a list. This is what the monitoring app calls.</summary>
    [HttpPost("Ingest/{listId:long}")]
    public async Task<IActionResult> Ingest(long listId, CancellationToken ct)
        => Ok(await _ingest.IngestListAsync(listId, ct));

    /// <summary>Dev-only. POST a raw twitterapi.io body and store it.</summary>
    [HttpPost("IngestJson/{listId:long}")]
    public async Task<IActionResult> IngestJson(long listId, CancellationToken ct)
    {
        if (!HttpContext.RequestServices
                .GetRequiredService<IWebHostEnvironment>().IsDevelopment())
        {
            return NotFound();
        }

        using var reader = new StreamReader(Request.Body);
        var json = await reader.ReadToEndAsync(ct);

        if (string.IsNullOrWhiteSpace(json))
        {
            return BadRequest(new { error = "Empty request body." });
        }

        return Ok(await _ingest.IngestJsonAsync(listId, json, ct));
    }
}
CSEOF

cat > RotoMonsterTwitter.API/Controllers/ListsController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/lists")]
public class ListsController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public ListsController(TwitterDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
        => Ok(await _db.TwitterLists.OrderBy(l => l.ListId).ToListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Save(
        [FromBody] TwitterList list, CancellationToken ct)
    {
        if (list.ListId <= 0)
        {
            return BadRequest(new { error = "ListId is required." });
        }

        var existing = await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == list.ListId, ct);

        if (existing == null)
        {
            _db.TwitterLists.Add(list);
        }
        else
        {
            existing.SportId = list.SportId;
            existing.Name = list.Name;
            existing.IsActive = list.IsActive;
        }

        await _db.SaveChangesAsync(ct);

        return Ok(await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == list.ListId, ct));
    }

    /// <summary>Reset a list's cursor so the next pull starts from scratch.</summary>
    [HttpPost("{listId:long}/reset")]
    public async Task<IActionResult> Reset(long listId, CancellationToken ct)
    {
        var list = await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == listId, ct);

        if (list == null)
        {
            return NotFound(new { error = $"No list with id {listId}." });
        }

        list.LastFetchedUnix = 0;
        await _db.SaveChangesAsync(ct);

        return Ok(list);
    }
}
CSEOF

echo "Writing Program.cs..."

cat > RotoMonsterTwitter.API/Program.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.API.Middleware;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<TwitterDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("TwitterDb")));

builder.Services.Configure<TwitterApiOptions>(
    builder.Configuration.GetSection(TwitterApiOptions.SectionName));

builder.Services.Configure<TwitterPostOptions>(
    builder.Configuration.GetSection(TwitterPostOptions.SectionName));

builder.Services.Configure<ApiKeyOptions>(
    builder.Configuration.GetSection(ApiKeyOptions.SectionName));

builder.Services.AddHttpClient<ITwitterApiService, TwitterApiService>((sp, client) =>
{
    var options = sp.GetRequiredService<IOptions<TwitterApiOptions>>().Value;
    client.DefaultRequestHeaders.Add("X-API-Key", options.ApiKey);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddHttpClient<ITwitterPosterService, TwitterPosterService>(
    client => client.Timeout = TimeSpan.FromSeconds(30));

builder.Services.AddScoped<ITweetService, TweetService>();
builder.Services.AddScoped<ITweetIngestService, TweetIngestService>();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseMiddleware<ApiKeyMiddleware>();

app.MapControllers();

app.MapGet("/health", async (TwitterDbContext db) =>
{
    var canConnect = await db.Database.CanConnectAsync();
    return Results.Ok(new { database = canConnect ? "connected" : "unreachable" });
});

app.Run();
CSEOF

echo "Writing client..."

cat > RotoMonsterTwitter.Client/RotoMonsterTwitterClientOptions.cs <<'CSEOF'
namespace RotoMonsterTwitter.Client;

public class RotoMonsterTwitterClientOptions
{
    public const string SectionName = "RotoMonsterTwitter";

    /// <summary>Root url of the API, e.g. https://twitter.rotomonster.com</summary>
    public string BaseUrl { get; set; } = "";

    /// <summary>Sent as X-API-Key on every request.</summary>
    public string ApiKey { get; set; } = "";

    public int TimeoutSeconds { get; set; } = 30;
}
CSEOF

cat > RotoMonsterTwitter.Client/IRotoMonsterTwitterClient.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Client;

public interface IRotoMonsterTwitterClient
{
    Task<GetTweetsResult> GetTweetsAsync(GetTweetsRequest request,
        CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsBySportAsync(int sportId, int maxResults = 100,
        CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsByUserAsync(string screenUsername,
        int maxResults = 100, CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsSinceAsync(int sportId, DateTime createdOnOrAfter,
        int maxResults = 100, CancellationToken ct = default);

    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);

    Task<GetTweetsResult> ReadTweetListAsync(long listId, int maxResults = 100,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsAsync(DeleteTweetsRequest request,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsOlderThanAsync(DateTime createdBefore,
        int? sportId = null, CancellationToken ct = default);

    /// <summary>Pull new tweets for a list. Call this on a schedule.</summary>
    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);

    /// <summary>Post a tweet through the API's X credentials.</summary>
    Task<PostTweetResult> PostTweetAsync(string text, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Client/RotoMonsterTwitterClient.cs <<'CSEOF'
using System.Net.Http.Json;
using System.Text.Json;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Client;

public class RotoMonsterTwitterClient : IRotoMonsterTwitterClient
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _http;

    /// <summary>
    /// Preferred constructor. Register with AddHttpClient so connections pool.
    /// </summary>
    public RotoMonsterTwitterClient(HttpClient http)
    {
        _http = http;
    }

    /// <summary>
    /// Convenience constructor for scripts and one-off callers. Creates its own
    /// HttpClient, so hold the instance rather than newing one per call.
    /// </summary>
    public RotoMonsterTwitterClient(string baseUrl, string apiKey = "",
        int timeoutSeconds = 30)
        : this(Build(baseUrl, apiKey, timeoutSeconds))
    {
    }

    private static HttpClient Build(string baseUrl, string apiKey, int timeoutSeconds)
    {
        var client = new HttpClient
        {
            BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"),
            Timeout = TimeSpan.FromSeconds(timeoutSeconds)
        };

        if (!string.IsNullOrWhiteSpace(apiKey))
        {
            client.DefaultRequestHeaders.Add("X-API-Key", apiKey);
        }

        return client;
    }

    // ---------------------------------------------------------------- reads

    public Task<GetTweetsResult> GetTweetsAsync(
        GetTweetsRequest request, CancellationToken ct = default)
        => PostAsync<GetTweetsRequest, GetTweetsResult>(
            "api/tweets/GetTweets", request, ct);

    public Task<GetTweetsResult> GetTweetsBySportAsync(
        int sportId, int maxResults = 100, CancellationToken ct = default)
        => GetTweetsAsync(new GetTweetsRequest
        {
            SportId = sportId,
            MaxResults = maxResults
        }, ct);

    public Task<GetTweetsResult> GetTweetsByUserAsync(
        string screenUsername, int maxResults = 100, CancellationToken ct = default)
        => GetTweetsAsync(new GetTweetsRequest
        {
            ScreenUsername = screenUsername,
            MaxResults = maxResults
        }, ct);

    public Task<GetTweetsResult> GetTweetsSinceAsync(
        int sportId, DateTime createdOnOrAfter, int maxResults = 100,
        CancellationToken ct = default)
        => GetTweetsAsync(new GetTweetsRequest
        {
            SportId = sportId,
            CreatedOnOrAfter = createdOnOrAfter,
            MaxResults = maxResults
        }, ct);

    public async Task<ReadTweetResult> ReadTweetAsync(
        string tweetId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(tweetId))
        {
            return new ReadTweetResult
            {
                Success = false,
                ErrorMessage = "TweetId is required."
            };
        }

        return await GetAsync<ReadTweetResult>(
            $"api/tweets/ReadTweet/{Uri.EscapeDataString(tweetId)}", ct);
    }

    public Task<GetTweetsResult> ReadTweetListAsync(
        long listId, int maxResults = 100, CancellationToken ct = default)
        => GetAsync<GetTweetsResult>(
            $"api/tweets/ReadTweetList/{listId}?maxResults={maxResults}", ct);

    // -------------------------------------------------------------- deletes

    public Task<DeleteTweetsResult> DeleteTweetsAsync(
        DeleteTweetsRequest request, CancellationToken ct = default)
        => PostAsync<DeleteTweetsRequest, DeleteTweetsResult>(
            "api/tweets/DeleteTweets", request, ct);

    public Task<DeleteTweetsResult> DeleteTweetsOlderThanAsync(
        DateTime createdBefore, int? sportId = null, CancellationToken ct = default)
        => DeleteTweetsAsync(new DeleteTweetsRequest
        {
            CreatedBefore = createdBefore,
            SportId = sportId
        }, ct);

    // --------------------------------------------------------------- ingest

    public Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default)
        => PostAsync<object, IngestResult>($"api/tweets/Ingest/{listId}", new { }, ct);

    // ----------------------------------------------------------------- post

    public Task<PostTweetResult> PostTweetAsync(
        string text, CancellationToken ct = default)
        => PostAsync<PostTweetRequest, PostTweetResult>(
            "api/tweets/PostTweet", new PostTweetRequest { Text = text }, ct);

    // -------------------------------------------------------------- plumbing

    private async Task<TResult> GetAsync<TResult>(string path, CancellationToken ct)
        where TResult : BaseResult, new()
    {
        try
        {
            var response = await _http.GetAsync(path, ct);
            return await ReadResultAsync<TResult>(response, ct);
        }
        catch (Exception ex)
        {
            return Failed<TResult>(ex);
        }
    }

    private async Task<TResult> PostAsync<TRequest, TResult>(
        string path, TRequest body, CancellationToken ct)
        where TResult : BaseResult, new()
    {
        try
        {
            var response = await _http.PostAsJsonAsync(path, body, JsonOptions, ct);
            return await ReadResultAsync<TResult>(response, ct);
        }
        catch (Exception ex)
        {
            return Failed<TResult>(ex);
        }
    }

    private static async Task<TResult> ReadResultAsync<TResult>(
        HttpResponseMessage response, CancellationToken ct)
        where TResult : BaseResult, new()
    {
        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(ct);
            return new TResult
            {
                Success = false,
                ErrorMessage = $"API returned {(int)response.StatusCode}: {Trim(body)}"
            };
        }

        var result = await response.Content.ReadFromJsonAsync<TResult>(JsonOptions, ct);

        return result ?? new TResult
        {
            Success = false,
            ErrorMessage = "API returned an empty response."
        };
    }

    private static TResult Failed<TResult>(Exception ex) where TResult : BaseResult, new()
        => new() { Success = false, ErrorMessage = ex.Message };

    private static string Trim(string value)
        => value.Length > 300 ? value[..300] + "..." : value;
}
CSEOF

# ClientTest, if it's still around, needs the key argument.
if [ -f RotoMonsterTwitter.ClientTest/Program.cs ]; then
  echo "Updating ClientTest..."
  python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("RotoMonsterTwitter.ClientTest/Program.cs")
text = p.read_text()
if "var apiKey" not in text:
    text = text.replace(
        "var client = new RotoMonsterTwitterClient(baseUrl);",
        "var apiKey = args.Length > 1 ? args[1] : \"\";\n"
        "var client = new RotoMonsterTwitterClient(baseUrl, apiKey);")
    text = text.replace(
        "var broken = new RotoMonsterTwitterClient(\"http://localhost:9\");",
        "var broken = new RotoMonsterTwitterClient(\"http://localhost:9\", apiKey);")
    p.write_text(text)
    print("  patched ClientTest Program.cs")
PYEOF
fi

echo ""
echo "Building..."
echo ""
dotnet build

KEY="rmt_$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 40)"

cat <<MSGEOF

==================================================================
Done. Here's a generated API key to use:

  $KEY

Add it to appsettings.Production.json on the server:

  "ApiKeys": {
    "Clients": {
      "monitoring": "$KEY"
    }
  }

Calling it:

  curl https://twitter.rotomonster.com/api/lists \\
       -H "X-API-Key: $KEY"

  curl -X POST https://twitter.rotomonster.com/api/tweets/Ingest/1687210426440847362 \\
       -H "X-API-Key: $KEY"

In Development with no keys configured, the check is skipped.
In Production, no keys means every request is refused.
/health stays open either way.

No in-app scheduler - Ken's monitoring apps call Ingest.
==================================================================
MSGEOF
