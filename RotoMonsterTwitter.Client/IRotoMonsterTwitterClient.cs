using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Client;

public interface IRotoMonsterTwitterClient
{
    Task<GetTweetsResult> GetTweetsAsync(GetTweetsRequest request, CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsBySportAsync(int sportId, int maxResults = 100,
        CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsByUserAsync(string screenUsername, int maxResults = 100,
        CancellationToken ct = default);

    Task<GetTweetsResult> GetTweetsSinceAsync(int sportId, DateTime createdOnOrAfter,
        int maxResults = 100, CancellationToken ct = default);

    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);

    Task<GetTweetsResult> ReadTweetListAsync(long listId, int maxResults = 100,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsAsync(DeleteTweetsRequest request,
        CancellationToken ct = default);

    Task<DeleteTweetsResult> DeleteTweetsOlderThanAsync(DateTime createdBefore,
        int? sportId = null, CancellationToken ct = default);

    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);

    /// <summary>
    /// Not implemented. See PostTweetAsync in RotoMonsterTwitterClient for why.
    /// </summary>
    Task<BaseResult> PostTweetAsync(string text, CancellationToken ct = default);
}
