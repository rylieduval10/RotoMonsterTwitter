using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public class TweetIngestService : ITweetIngestService
{
    private readonly TwitterDbContext _db;
    private readonly ITweetProcessingService _processing;
    private readonly ITwitterApiService _api;
    private readonly TwitterApiOptions _options;

    public TweetIngestService(TwitterDbContext db, ITwitterApiService api,
        IOptions<TwitterApiOptions> options,
        ITweetProcessingService processing)
    {
        _db = db;
        _api = api;
        _options = options.Value;
        _processing = processing;
    }

    public async Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default)
    {
        var (list, result) = await LoadListAsync(listId, ct);
        if (list == null) return result;

        var collected = new List<ParsedTweet>();
        string? cursor = null;

        for (var page = 0; page < Math.Max(1, _options.MaxPagesPerFetch); page++)
        {
            var fetched = await _api.GetListTweetsPageAsync(listId, list.LastFetchedUnix, cursor, ct);
            result.PagesFetched++;
            collected.AddRange(fetched.Tweets);

            if (!fetched.HasNextPage || string.IsNullOrWhiteSpace(fetched.NextCursor))
            {
                break;
            }

            cursor = fetched.NextCursor;
        }

        return await PersistAsync(list, collected, result, ct);
    }

    public async Task<IngestResult> IngestJsonAsync(long listId, string json,
        CancellationToken ct = default)
    {
        var (list, result) = await LoadListAsync(listId, ct);
        if (list == null) return result;

        TweetPage page;
        try
        {
            page = TwitterApiService.ParsePage(json);
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.ErrorMessage = $"Could not parse the supplied JSON: {ex.Message}";
            return result;
        }

        result.PagesFetched = 1;
        return await PersistAsync(list, page.Tweets, result, ct);
    }

    private async Task<(TwitterList? list, IngestResult result)> LoadListAsync(
        long listId, CancellationToken ct)
    {
        var list = await _db.TwitterLists.FirstOrDefaultAsync(l => l.ListId == listId, ct);

        if (list == null)
        {
            return (null, new IngestResult
            {
                Success = false,
                ListId = listId,
                ErrorMessage = $"No list configured with id {listId}. Add a row to TwitterLists first."
            });
        }

        return (list, new IngestResult
        {
            ListId = listId,
            SportId = list.SportId,
            PreviousSinceUnix = list.LastFetchedUnix,
            NewSinceUnix = list.LastFetchedUnix
        });
    }

    private async Task<IngestResult> PersistAsync(TwitterList list,
        List<ParsedTweet> collected, IngestResult result, CancellationToken ct)
    {
        result.TweetsReturned = collected.Count;

        if (collected.Count == 0)
        {
            list.LastFetchedAt = DateTime.UtcNow;
            list.LastTweetCount = 0;
            await _db.SaveChangesAsync(ct);
            return result;
        }

        // Users first, so the FK on Tweets resolves.
        var incomingUsers = collected
            .GroupBy(p => p.User.TwitterUserId)
            .Select(g => g.Last().User)
            .ToList();

        var incomingUserIds = incomingUsers.Select(u => u.TwitterUserId).ToList();

        var existingUsers = await _db.TweetUsers
            .Where(u => incomingUserIds.Contains(u.TwitterUserId))
            .ToDictionaryAsync(u => u.TwitterUserId, ct);

        foreach (var incoming in incomingUsers)
        {
            if (existingUsers.TryGetValue(incoming.TwitterUserId, out var existing))
            {
                existing.ScreenUsername = incoming.ScreenUsername;
                existing.DisplayName = incoming.DisplayName;
                existing.ImageUrl = incoming.ImageUrl;
                existing.IsVerified = incoming.IsVerified;
                existing.IsBlueVerified = incoming.IsBlueVerified;
                existing.VerifiedType = incoming.VerifiedType;
                existing.LastSeenAt = DateTime.UtcNow;
            }
            else
            {
                _db.TweetUsers.Add(incoming);
                result.NewUsers++;
            }
        }

        await _db.SaveChangesAsync(ct);

        // Then tweets, skipping any already stored.
        var incomingIds = collected.Select(p => p.Tweet.TweetId).Distinct().ToList();

        var existingIds = await _db.Tweets
            .Where(t => incomingIds.Contains(t.TweetId))
            .Select(t => t.TweetId)
            .ToListAsync(ct);

        var existingSet = existingIds.ToHashSet();
        var seen = new HashSet<string>();

        foreach (var parsed in collected)
        {
            if (existingSet.Contains(parsed.Tweet.TweetId)) continue;
            if (!seen.Add(parsed.Tweet.TweetId)) continue;

            parsed.Tweet.SportId = list.SportId;
            parsed.Tweet.Media = parsed.Media;

            _db.Tweets.Add(parsed.Tweet);
            result.NewTweets++;
        }

        // Advance the cursor to the newest tweet seen.
        var newest = collected.Max(p => p.Tweet.CreatedDate);
        var newestUnix = TwitterApiService.ToUnix(DateTime.SpecifyKind(newest, DateTimeKind.Utc));

        if (newestUnix > list.LastFetchedUnix)
        {
            list.LastFetchedUnix = newestUnix;
        }

        list.LastFetchedAt = DateTime.UtcNow;
        list.LastTweetCount = result.TweetsReturned;
        result.NewSinceUnix = list.LastFetchedUnix;

        await _db.SaveChangesAsync(ct);

        // A pull should leave tweets ready to read, so process the new ones now.
        if (result.Success && result.NewTweets > 0)
        {
            try
            {
                var processed = await _processing.ProcessAsync(
                    batchSize: Math.Max(result.NewTweets, 100),
                    reprocessAll: false, ct: ct);

                result.TweetsProcessed = processed.TweetsProcessed;
                result.MatchesCreated = processed.KeywordMatches
                    + processed.PlayerMatches + processed.TeamMatches;
            }
            catch
            {
                // Ingest succeeded; don't fail the whole call if the follow-on
                // processing hiccups. The tweets are stored and the next run
                // will process them.
            }
        }

        return result;
    }
}
