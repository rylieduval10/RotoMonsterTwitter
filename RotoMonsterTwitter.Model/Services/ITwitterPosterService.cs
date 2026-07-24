using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITwitterPosterService
{
    Task<PostTweetResult> PostTweetAsync(string text, CancellationToken ct = default);
}
