using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public class TweetService : ITweetService
{
    private readonly TwitterDbContext _db;

    public TweetService(TwitterDbContext db) => _db = db;

    public async Task<GetTweetsResult> GetTweetsAsync(
        GetTweetsRequest request, CancellationToken ct = default)
    {
        var query = _db.Tweets
            .Include(t => t.TweetUser)
            .Include(t => t.Media)
            .AsQueryable();

        if (request.SportId.HasValue)
            query = query.Where(t => t.SportId == request.SportId.Value);

        if (!string.IsNullOrWhiteSpace(request.ScreenUsername))
            query = query.Where(t => t.TweetUser!.ScreenUsername.ToLower()
                                     == request.ScreenUsername.ToLower());

        if (request.CreatedOnOrAfter.HasValue)
            query = query.Where(t => t.CreatedDate >= request.CreatedOnOrAfter.Value);

        if (request.CreatedOnOrBefore.HasValue)
            query = query.Where(t => t.CreatedDate <= request.CreatedOnOrBefore.Value);

        if (!string.IsNullOrWhiteSpace(request.SearchText))
            query = query.Where(t => EF.Functions.ILike(t.Text, $"%{request.SearchText}%"));

        var total = await query.CountAsync(ct);

        var tweets = await query
            .OrderByDescending(t => t.CreatedDate)
            .Skip(Math.Max(0, request.Skip))
            .Take(Math.Clamp(request.MaxResults, 1, 500))
            .ToListAsync(ct);

        return new GetTweetsResult
        {
            TotalCount = total,
            Tweets = tweets.Select(Map).ToList()
        };
    }

    public async Task<ReadTweetResult> ReadTweetAsync(
        string tweetId, CancellationToken ct = default)
    {
        var tweet = await _db.Tweets
            .Include(t => t.TweetUser)
            .Include(t => t.Media)
            .FirstOrDefaultAsync(t => t.TweetId == tweetId, ct);

        return tweet == null
            ? new ReadTweetResult { Success = false, ErrorMessage = $"No tweet found with id {tweetId}." }
            : new ReadTweetResult { Tweet = Map(tweet) };
    }

    public async Task<GetTweetsResult> ReadTweetListAsync(
        long listId, int maxResults = 100, CancellationToken ct = default)
    {
        var list = await _db.TwitterLists.FirstOrDefaultAsync(l => l.ListId == listId, ct);

        if (list == null)
        {
            return new GetTweetsResult
            {
                Success = false,
                ErrorMessage = $"No list configured with id {listId}."
            };
        }

        return await GetTweetsAsync(new GetTweetsRequest
        {
            SportId = list.SportId,
            MaxResults = maxResults
        }, ct);
    }

    public async Task<DeleteTweetsResult> DeleteTweetsAsync(
        DeleteTweetsRequest request, CancellationToken ct = default)
    {
        var hasIds = request.TweetIds is { Count: > 0 };

        if (!hasIds && !request.CreatedBefore.HasValue)
        {
            return new DeleteTweetsResult
            {
                Success = false,
                ErrorMessage = "Supply TweetIds or CreatedBefore. Refusing to delete everything."
            };
        }

        var query = _db.Tweets.AsQueryable();

        if (hasIds)
            query = query.Where(t => request.TweetIds!.Contains(t.TweetId));

        if (request.CreatedBefore.HasValue)
            query = query.Where(t => t.CreatedDate < request.CreatedBefore.Value);

        if (request.SportId.HasValue)
            query = query.Where(t => t.SportId == request.SportId.Value);

        var deleted = await query.ExecuteDeleteAsync(ct);

        return new DeleteTweetsResult { DeletedCount = deleted };
    }

    private static TweetResult Map(Tweet t) => new()
    {
        TweetId = t.TweetId,
        SportId = t.SportId,
        CreatedDate = t.CreatedDate,
        Text = t.Text,
        TwitterUserId = t.TwitterUserId,
        ScreenUsername = t.TweetUser?.ScreenUsername ?? "",
        DisplayName = t.TweetUser?.DisplayName ?? "",
        ImageUrl = t.TweetUser?.ImageUrl ?? "",
        IsVerified = t.TweetUser?.IsVerified ?? false,
        IsBlueVerified = t.TweetUser?.IsBlueVerified ?? false,
        IsRetweet = t.IsRetweet,
        RetweetDate = t.RetweetDate,
        RetweetUserScreenName = t.RetweetUserScreenName,
        SourceTweetId = t.SourceTweetId,
        SourceTweetUserScreenName = t.SourceTweetUserScreenName,
        RetweetCount = t.RetweetCount,
        Followers = t.Followers,
        Media = t.Media
            .OrderBy(i => i.DisplayOrder)
            .Select(i => new TweetMediaResult
            {
                ImageUrl = i.ImageUrl,
                MediaType = i.MediaType,
                VideoUrl = i.VideoUrl,
                DurationMillis = i.DurationMillis,
                DisplayOrder = i.DisplayOrder
            }).ToList()
    };
}
