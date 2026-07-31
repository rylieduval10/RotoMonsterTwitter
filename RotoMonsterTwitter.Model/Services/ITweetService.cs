using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetService
{
    Task<GetTweetsResult> GetTweetsAsync(GetTweetsRequest request, CancellationToken ct = default);
    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);
    Task<GetTweetsResult> ReadTweetListAsync(long listId, int maxResults = 100, CancellationToken ct = default);
    Task<DeleteTweetsResult> DeleteTweetsAsync(DeleteTweetsRequest request, CancellationToken ct = default);
    Task<SetAiTextResult> SetAiTextAsync(SetAiTextRequest request, CancellationToken ct = default);
}
