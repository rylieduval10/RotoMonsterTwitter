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
    /// Preferred constructor. Register with AddHttpClient so connections are pooled.
    /// </summary>
    public RotoMonsterTwitterClient(HttpClient http)
    {
        _http = http;
    }

    /// <summary>
    /// Convenience constructor for scripts and one-off callers. Creates its own
    /// HttpClient, so hold onto the instance rather than newing one per call.
    /// </summary>
    public RotoMonsterTwitterClient(string baseUrl, int timeoutSeconds = 30)
        : this(new HttpClient
        {
            BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"),
            Timeout = TimeSpan.FromSeconds(timeoutSeconds)
        })
    {
    }

    // ---------------------------------------------------------------- reads

    public Task<GetTweetsResult> GetTweetsAsync(
        GetTweetsRequest request, CancellationToken ct = default)
        => PostAsync<GetTweetsRequest, GetTweetsResult>("api/tweets/GetTweets", request, ct);

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
            return new ReadTweetResult { Success = false, ErrorMessage = "TweetId is required." };
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

    /// <summary>
    /// Ken's spec asks for posting a tweet from the client. This is not built yet:
    /// twitterapi.io is a read API, so posting means going through X's own API,
    /// which needs its own developer account, OAuth credentials and paid tier.
    /// Waiting on Ken to confirm the account before wiring it up.
    /// </summary>
    public Task<BaseResult> PostTweetAsync(string text, CancellationToken ct = default)
        => Task.FromResult(new BaseResult
        {
            Success = false,
            ErrorMessage = "Posting is not implemented yet - pending X API credentials."
        });

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
