using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;

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

        if (request.IsNews.HasValue)
            query = query.Where(t => t.TweetUser!.IsNews == request.IsNews.Value);

        if (request.IsTop.HasValue)
            query = query.Where(t => t.TweetUser!.IsTop == request.IsTop.Value);

        if (request.CreatedOnOrAfter.HasValue)
            query = query.Where(t => t.CreatedDate >= request.CreatedOnOrAfter.Value);

        if (request.CreatedOnOrBefore.HasValue)
            query = query.Where(t => t.CreatedDate <= request.CreatedOnOrBefore.Value);

        if (request.AddedOnOrAfter.HasValue)
            query = query.Where(t => t.DateAdded >= request.AddedOnOrAfter.Value);

        if (request.AddedOnOrBefore.HasValue)
            query = query.Where(t => t.DateAdded <= request.AddedOnOrBefore.Value);

        if (!string.IsNullOrWhiteSpace(request.SearchText))
            query = query.Where(t => EF.Functions.ILike(t.Text, $"%{request.SearchText}%"));

        var total = await query.CountAsync(ct);

        query = request.OrderByDateAdded
            ? query.OrderByDescending(t => t.DateAdded).ThenByDescending(t => t.CreatedDate)
            : query.OrderByDescending(t => t.CreatedDate);

        var tweets = await query
            .Skip(Math.Max(0, request.Skip))
            .Take(Math.Clamp(request.MaxResults, 1, 500))
            .ToListAsync(ct);

        var results = await MapManyAsync(tweets, ct);

        return new GetTweetsResult { TotalCount = total, Tweets = results };
    }

    public async Task<ReadTweetResult> ReadTweetAsync(
        string tweetId, CancellationToken ct = default)
    {
        var tweet = await _db.Tweets
            .Include(t => t.TweetUser)
            .Include(t => t.Media)
            .FirstOrDefaultAsync(t => t.TweetId == tweetId, ct);

        if (tweet == null)
        {
            return new ReadTweetResult
            {
                Success = false,
                ErrorMessage = $"No tweet found with id {tweetId}."
            };
        }

        var mapped = await MapManyAsync(new List<Tweet> { tweet }, ct);
        return new ReadTweetResult { Tweet = mapped[0] };
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

    /// <summary>
    /// Loads the player, team and keyword matches for a set of tweets in three
    /// batched queries, then attaches them - avoids a per-tweet round trip and
    /// avoids Include-multiplication on the main query.
    /// </summary>
    private async Task<List<TweetResult>> MapManyAsync(
        List<Tweet> tweets, CancellationToken ct)
    {
        var ids = tweets.Select(t => t.TweetId).ToList();

        var playerMatches = await (
            from tp in _db.TweetPlayers
            join p in _db.TwitterPlayers on tp.PlayerId equals p.PlayerId
            where ids.Contains(tp.TweetId)
            select new
            {
                tp.TweetId, tp.PlayerId, p.FirstName, p.LastName, p.TeamId,
                tp.MatchType, tp.Confidence, tp.Occurrences
            }).ToListAsync(ct);

        var teamMatches = await (
            from tt in _db.TweetTeams
            join t in _db.TwitterTeams on tt.TeamId equals t.TeamId
            where ids.Contains(tt.TweetId)
            select new
            {
                tt.TweetId, tt.TeamId, t.City, t.Name,
                tt.MatchType, tt.Confidence, tt.Occurrences
            }).ToListAsync(ct);

        var keywordMatches = await (
            from tk in _db.TweetKeywords
            join k in _db.TwitterKeywords on tk.KeywordId equals k.Id
            where ids.Contains(tk.TweetId)
            select new
            {
                tk.TweetId, tk.KeywordId, k.Keyword, k.Category, k.Weight, tk.Occurrences
            }).ToListAsync(ct);

        var playersByTweet = playerMatches.GroupBy(x => x.TweetId)
            .ToDictionary(g => g.Key, g => g.ToList());
        var teamsByTweet = teamMatches.GroupBy(x => x.TweetId)
            .ToDictionary(g => g.Key, g => g.ToList());
        var keywordsByTweet = keywordMatches.GroupBy(x => x.TweetId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var results = new List<TweetResult>(tweets.Count);

        foreach (var t in tweets)
        {
            var result = new TweetResult
            {
                TweetId = t.TweetId,
                SportId = t.SportId,
                CreatedDate = t.CreatedDate,
                DateAdded = t.DateAdded,
                Text = t.Text,
                TwitterUserId = t.TwitterUserId,
                ScreenUsername = t.TweetUser?.ScreenUsername ?? "",
                DisplayName = t.TweetUser?.DisplayName ?? "",
                ImageUrl = t.TweetUser?.ImageUrl ?? "",
                IsVerified = t.TweetUser?.IsVerified ?? false,
                IsBlueVerified = t.TweetUser?.IsBlueVerified ?? false,
                IsNews = t.TweetUser?.IsNews ?? false,
                IsTop = t.TweetUser?.IsTop ?? false,
                IsRetweet = t.IsRetweet,
                RetweetDate = t.RetweetDate,
                RetweetUserScreenName = t.RetweetUserScreenName,
                SourceTweetId = t.SourceTweetId,
                SourceTweetUserScreenName = t.SourceTweetUserScreenName,
                RetweetCount = t.RetweetCount,
                Followers = t.Followers,
                ProcessedAt = t.ProcessedAt,
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

            if (playersByTweet.TryGetValue(t.TweetId, out var pm))
            {
                result.Players = pm
                    .OrderByDescending(x => x.Confidence)
                    .ThenBy(x => x.LastName)
                    .Select(x => new TweetPlayerMatch
                    {
                        PlayerId = x.PlayerId,
                        FirstName = x.FirstName,
                        LastName = x.LastName,
                        TeamId = x.TeamId,
                        MatchType = x.MatchType,
                        Confidence = x.Confidence,
                        Occurrences = x.Occurrences
                    }).ToList();
            }

            if (teamsByTweet.TryGetValue(t.TweetId, out var tm))
            {
                result.Teams = tm
                    .OrderByDescending(x => x.Confidence)
                    .Select(x => new TweetTeamMatch
                    {
                        TeamId = x.TeamId,
                        City = x.City,
                        Name = x.Name,
                        MatchType = x.MatchType,
                        Confidence = x.Confidence,
                        Occurrences = x.Occurrences
                    }).ToList();
            }

            if (keywordsByTweet.TryGetValue(t.TweetId, out var km))
            {
                result.Keywords = km
                    .OrderByDescending(x => x.Weight)
                    .ThenBy(x => x.Category)
                    .Select(x => new TweetKeywordMatch
                    {
                        KeywordId = x.KeywordId,
                        Keyword = x.Keyword,
                        Category = x.Category,
                        Weight = x.Weight,
                        Occurrences = x.Occurrences
                    }).ToList();
            }

            results.Add(result);
        }

        return results;
    }
}
