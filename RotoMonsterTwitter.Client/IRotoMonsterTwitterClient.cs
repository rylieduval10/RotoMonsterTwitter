using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;

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

    /// <summary>
    /// Everything stored since the given point, newest first. Pass the
    /// DateAdded of the newest tweet you already handled.
    /// </summary>
    Task<GetTweetsResult> GetTweetsAddedSinceAsync(DateTime addedOnOrAfter,
        int? sportId = null, int maxResults = 100, CancellationToken ct = default);

    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);

    Task<GetTweetsResult> ReadTweetListAsync(long listId, int maxResults = 100,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsAsync(DeleteTweetsRequest request,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsOlderThanAsync(DateTime createdBefore,
        int? sportId = null, CancellationToken ct = default);

    /// <summary>Pull new tweets for a list. Call this on a schedule.</summary>
    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);

    /// <summary>
    /// Summarize a tweet with AI (the Auto Fill button). Returns the summary
    /// text; you decide where it goes.
    /// </summary>
    Task<AnalyzeTweetResult> AnalyzeWithAIAsync(string text, string? tweetId = null,
        CancellationToken ct = default);

    /// <summary>
    /// Replace the player and team pool for a sport. Send the complete
    /// set each time - anything missing from it is dropped.
    /// </summary>
    Task<ImportResult> ImportPlayersAsync(PlayerImportRequest request,
        CancellationToken ct = default);

    /// <summary>Browse stored users, optionally filtered by flag.</summary>
    Task<GetUsersResult> GetUsersAsync(GetUsersRequest request,
        CancellationToken ct = default);

    /// <summary>
    /// Set IsNews / IsTop on specific users. Only the users you send are
    /// touched; a null flag is left as it was.
    /// </summary>
    Task<SetUserFlagsResult> SetUserFlagsAsync(SetUserFlagsRequest request,
        CancellationToken ct = default);

    /// <summary>Tweets from IsNews accounts only.</summary>
    Task<GetTweetsResult> GetNewsTweetsAsync(int sportId, int maxResults = 100,
        CancellationToken ct = default);

    /// <summary>Tweets from IsTop accounts only.</summary>
    Task<GetTweetsResult> GetTopTweetsAsync(int sportId, int maxResults = 100,
        CancellationToken ct = default);

    /// <summary>The status vocabulary players can be tagged with.</summary>
    Task<GetPlayerStatusTypesResult> GetPlayerStatusTypesAsync(
        CancellationToken ct = default);

    /// <summary>Browse stored players and their current statuses.</summary>
    Task<GetPlayersResult> GetPlayersAsync(GetPlayersRequest request,
        CancellationToken ct = default);

    /// <summary>
    /// Set the status on specific players. Only the players you send are
    /// touched; a null status id clears it.
    /// </summary>
    Task<SetPlayerStatusResult> SetPlayerStatusAsync(SetPlayerStatusRequest request,
        CancellationToken ct = default);

    /// <summary>Post a tweet through the API's X credentials.</summary>
    Task<PostTweetResult> PostTweetAsync(string text, CancellationToken ct = default);
}
