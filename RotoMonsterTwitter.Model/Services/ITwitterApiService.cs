namespace RotoMonsterTwitter.Model.Services;

public interface ITwitterApiService
{
    Task<string> GetListTweetsRawAsync(long listId, long sinceUnixTimestamp = 0,
        string? cursor = null, CancellationToken ct = default);

    Task<TweetPage> GetListTweetsPageAsync(long listId, long sinceUnixTimestamp = 0,
        string? cursor = null, CancellationToken ct = default);
}
