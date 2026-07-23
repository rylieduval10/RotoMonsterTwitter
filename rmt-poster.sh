#!/usr/bin/env bash
#
# RotoMonsterTwitter - add tweet posting via X API v2 with OAuth 1.0a signing,
# ported from Ken's SharedCS TwitterPoster class.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Writing post options..."

cat > RotoMonsterTwitter.Model/Configuration/TwitterPostOptions.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Configuration;

/// <summary>
/// OAuth 1.0a credentials for posting to X. These come from an X developer
/// app, not from twitterapi.io - twitterapi.io is read-only.
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
    /// <summary>Id of the tweet that was created, when the post succeeded.</summary>
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
/// Posts to X (Twitter) API v2 using OAuth 1.0a user-context signing.
/// Ported from Ken's SharedCS TwitterPoster, made async, with a fixed nonce
/// generator and the API's error body surfaced instead of swallowed.
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

        // The JSON body is NOT part of the signature base for v2 - only the
        // oauth parameters are, since the body is not form-encoded.
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

        var payload = new JObject { ["text"] = text }.ToString(
            Newtonsoft.Json.Formatting.None);

        var request = new HttpRequestMessage(HttpMethod.Post, _options.PostUrl)
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json")
        };

        request.Headers.Authorization = new AuthenticationHeaderValue("OAuth", header);

        return request;
    }

    /// <summary>
    /// RFC 3986 percent-encoding. Uri.EscapeDataString has varied across .NET
    /// versions on whether it escapes ! ' ( ) *, and OAuth signatures break if
    /// it guesses differently than the server, so this is explicit.
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

echo "Updating controller and Program..."

python3 - <<'PYEOF'
import pathlib

# --- controller: add the PostTweet endpoint ---
p = pathlib.Path("RotoMonsterTwitter.API/Controllers/TweetsController.cs")
text = p.read_text()

if "PostTweet" not in text:
    text = text.replace(
        "    private readonly ITweetService _tweets;\n"
        "    private readonly ITweetIngestService _ingest;\n"
        "\n"
        "    public TweetsController(ITweetService tweets, ITweetIngestService ingest)\n"
        "    {\n"
        "        _tweets = tweets;\n"
        "        _ingest = ingest;\n"
        "    }",
        "    private readonly ITweetService _tweets;\n"
        "    private readonly ITweetIngestService _ingest;\n"
        "    private readonly ITwitterPosterService _poster;\n"
        "\n"
        "    public TweetsController(ITweetService tweets, ITweetIngestService ingest,\n"
        "        ITwitterPosterService poster)\n"
        "    {\n"
        "        _tweets = tweets;\n"
        "        _ingest = ingest;\n"
        "        _poster = poster;\n"
        "    }")

    text = text.replace(
        "    [HttpPost(\"Ingest/{listId:long}\")]",
        "    [HttpPost(\"PostTweet\")]\n"
        "    public async Task<IActionResult> PostTweet([FromBody] PostTweetRequest request, CancellationToken ct)\n"
        "        => Ok(await _poster.PostTweetAsync(request.Text, ct));\n"
        "\n"
        "    [HttpPost(\"Ingest/{listId:long}\")]")

    p.write_text(text)
    print("  patched TweetsController.cs")
else:
    print("  TweetsController.cs already has PostTweet")

# --- Program.cs: register the poster ---
p = pathlib.Path("RotoMonsterTwitter.API/Program.cs")
text = p.read_text()

if "TwitterPostOptions" not in text:
    text = text.replace(
        "builder.Services.AddScoped<ITweetService, TweetService>();",
        "builder.Services.Configure<TwitterPostOptions>(\n"
        "    builder.Configuration.GetSection(TwitterPostOptions.SectionName));\n"
        "\n"
        "builder.Services.AddHttpClient<ITwitterPosterService, TwitterPosterService>(\n"
        "    client => client.Timeout = TimeSpan.FromSeconds(30));\n"
        "\n"
        "builder.Services.AddScoped<ITweetService, TweetService>();")

    p.write_text(text)
    print("  patched Program.cs")
else:
    print("  Program.cs already registers the poster")

# --- client: real PostTweetAsync ---
p = pathlib.Path("RotoMonsterTwitter.Client/RotoMonsterTwitterClient.cs")
text = p.read_text()

old_stub_start = text.find("    /// <summary>\n    /// Ken's spec asks for posting")
old_stub_end = text.find("    // -------------------------------------------------------------- plumbing")

if old_stub_start != -1 and old_stub_end != -1:
    replacement = (
        "    public Task<PostTweetResult> PostTweetAsync(\n"
        "        string text, CancellationToken ct = default)\n"
        "        => PostAsync<PostTweetRequest, PostTweetResult>(\n"
        "            \"api/tweets/PostTweet\", new PostTweetRequest { Text = text }, ct);\n"
        "\n"
    )
    text = text[:old_stub_start] + replacement + text[old_stub_end:]
    p.write_text(text)
    print("  patched RotoMonsterTwitterClient.cs")
else:
    print("  client stub not found - check PostTweetAsync by hand")

# --- client interface ---
p = pathlib.Path("RotoMonsterTwitter.Client/IRotoMonsterTwitterClient.cs")
text = p.read_text()
text = text.replace(
    "    /// <summary>\n"
    "    /// Not implemented. See PostTweetAsync in RotoMonsterTwitterClient for why.\n"
    "    /// </summary>\n"
    "    Task<BaseResult> PostTweetAsync(string text, CancellationToken ct = default);",
    "    /// <summary>Post a tweet through the API's X credentials.</summary>\n"
    "    Task<PostTweetResult> PostTweetAsync(string text, CancellationToken ct = default);")
p.write_text(text)
print("  patched IRotoMonsterTwitterClient.cs")
PYEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Credentials go in the TwitterPost config section - locally:

  cd RotoMonsterTwitter.API
  dotnet user-secrets set "TwitterPost:ConsumerKey"       "..."
  dotnet user-secrets set "TwitterPost:ConsumerSecret"    "..."
  dotnet user-secrets set "TwitterPost:AccessToken"       "..."
  dotnet user-secrets set "TwitterPost:AccessTokenSecret" "..."
  cd ..

Until they're set, PostTweet returns Success=false with a message
saying so - it won't throw or post anything.

To test once Ken sends them:

  curl -X POST http://localhost:5080/api/tweets/PostTweet \
       -H "Content-Type: application/json" \
       -d '{"text":"test from RotoMonsterTwitter"}'
==================================================================
MSGEOF
