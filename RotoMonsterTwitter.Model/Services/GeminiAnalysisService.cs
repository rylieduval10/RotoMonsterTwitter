using System.Text;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using RotoMonsterTwitter.Contracts.Results;
using RotoMonsterTwitter.Model.Configuration;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Summarizes a tweet via Google Gemini's generateContent endpoint. Returns a
/// failure result rather than throwing, matching the rest of the API - a down
/// AI provider should never 500 the caller.
/// </summary>
public class GeminiAnalysisService : IAiAnalysisService
{
    private readonly HttpClient _http;
    private readonly AiOptions _options;

    public GeminiAnalysisService(HttpClient http, IOptions<AiOptions> options)
    {
        _http = http;
        _options = options.Value;
    }

    public async Task<AnalyzeTweetResult> SummarizeAsync(
        string text, string? tweetId = null, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return Fail(tweetId, "Tweet text is required.");
        }

        if (!_options.IsConfigured)
        {
            return Fail(tweetId,
                "AI is not configured. Set the Ai:ApiKey (and Ai:Model) settings.");
        }

        var prompt = _options.PromptTemplate.Replace("{tweet}", text);

        var payload = new JObject
        {
            ["contents"] = new JArray
            {
                new JObject
                {
                    ["parts"] = new JArray { new JObject { ["text"] = prompt } }
                }
            }
        }.ToString(Formatting.None);

        // Key goes on the query string per Gemini's REST contract.
        var url = $"{_options.BaseUrl.TrimEnd('/')}/{_options.Model}:generateContent"
                + $"?key={Uri.EscapeDataString(_options.ApiKey)}";

        try
        {
            using var content = new StringContent(payload, Encoding.UTF8, "application/json");
            var response = await _http.PostAsync(url, content, ct);
            var body = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                return Fail(tweetId,
                    $"Gemini returned {(int)response.StatusCode}: {Trim(body)}");
            }

            var summary = ExtractText(body);

            if (string.IsNullOrWhiteSpace(summary))
            {
                return Fail(tweetId, "Gemini returned no text.");
            }

            return new AnalyzeTweetResult
            {
                TweetId = tweetId,
                Summary = summary.Trim(),
                Model = _options.Model
            };
        }
        catch (Exception ex)
        {
            return Fail(tweetId, ex.Message);
        }
    }

    /// <summary>
    /// Pulls candidates[0].content.parts[*].text out of the Gemini response,
    /// joining multiple parts if present.
    /// </summary>
    private static string ExtractText(string body)
    {
        var parts = JObject.Parse(body)["candidates"]?[0]?["content"]?["parts"];
        if (parts == null) return "";

        var sb = new StringBuilder();
        foreach (var part in parts)
        {
            sb.Append(part["text"]?.ToString());
        }
        return sb.ToString();
    }

    private static AnalyzeTweetResult Fail(string? tweetId, string message)
        => new() { Success = false, ErrorMessage = message, TweetId = tweetId };

    private static string Trim(string value)
        => value.Length > 400 ? value.Substring(0, 400) + "..." : value;
}
