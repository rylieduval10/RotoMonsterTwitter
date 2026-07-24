using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Contracts.Results;

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
