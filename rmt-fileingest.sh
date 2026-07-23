#!/usr/bin/env bash
#
# RotoMonsterTwitter - adds JSON-body ingest so the full store path can be
# tested against Ken's sample file, with no twitterapi.io call involved.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Updating ingest service..."

cat > RotoMonsterTwitter.Model/Services/ITweetIngestService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetIngestService
{
    /// <summary>Fetch from twitterapi.io and store.</summary>
    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);

    /// <summary>
    /// Store from a raw twitterapi.io response body already in hand.
    /// Used for testing the parse/store path without an HTTP call.
    /// </summary>
    Task<IngestResult> IngestJsonAsync(long listId, string json, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TweetIngestService.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public class TweetIngestService : ITweetIngestService
{
    private readonly TwitterDbContext _db;
    private readonly ITwitterApiService _api;
    private readonly TwitterApiOptions _options;

    public TweetIngestService(TwitterDbContext db, ITwitterApiService api,
        IOptions<TwitterApiOptions> options)
    {
        _db = db;
        _api = api;
        _options = options.Value;
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
            parsed.Tweet.Images = parsed.Media;

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

        return result;
    }
}
CSEOF

echo "Updating controller..."

cat > RotoMonsterTwitter.API/Controllers/TweetsController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/tweets")]
public class TweetsController : ControllerBase
{
    private readonly ITweetService _tweets;
    private readonly ITweetIngestService _ingest;

    public TweetsController(ITweetService tweets, ITweetIngestService ingest)
    {
        _tweets = tweets;
        _ingest = ingest;
    }

    [HttpPost("GetTweets")]
    public async Task<IActionResult> GetTweets([FromBody] GetTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.GetTweetsAsync(request, ct));

    [HttpGet("ReadTweet/{tweetId}")]
    public async Task<IActionResult> ReadTweet(string tweetId, CancellationToken ct)
        => Ok(await _tweets.ReadTweetAsync(tweetId, ct));

    [HttpGet("ReadTweetList/{listId:long}")]
    public async Task<IActionResult> ReadTweetList(long listId, [FromQuery] int maxResults = 100, CancellationToken ct = default)
        => Ok(await _tweets.ReadTweetListAsync(listId, maxResults, ct));

    [HttpPost("DeleteTweets")]
    public async Task<IActionResult> DeleteTweets([FromBody] DeleteTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.DeleteTweetsAsync(request, ct));

    [HttpPost("Ingest/{listId:long}")]
    public async Task<IActionResult> Ingest(long listId, CancellationToken ct)
        => Ok(await _ingest.IngestListAsync(listId, ct));

    /// <summary>
    /// Dev-only. POST a raw twitterapi.io response body and store it as if it
    /// had been fetched. Lets the parse/store path be exercised without a list id.
    /// </summary>
    [HttpPost("IngestJson/{listId:long}")]
    public async Task<IActionResult> IngestJson(long listId, CancellationToken ct)
    {
        if (!HttpContext.RequestServices
                .GetRequiredService<IWebHostEnvironment>().IsDevelopment())
        {
            return NotFound();
        }

        using var reader = new StreamReader(Request.Body);
        var json = await reader.ReadToEndAsync(ct);

        if (string.IsNullOrWhiteSpace(json))
        {
            return BadRequest(new { error = "Empty request body." });
        }

        return Ok(await _ingest.IngestJsonAsync(listId, json, ct));
    }
}
CSEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done.

1. Seed a placeholder list row (SportId 1 = basketball):

   psql -U postgres -d RotoMonsterTwitter -c \
   "INSERT INTO \"TwitterLists\" (\"ListId\",\"SportId\",\"Name\",\"IsActive\",\"LastFetchedUnix\",\"LastTweetCount\") \
    VALUES (1,1,'sample data',true,0,0) ON CONFLICT DO NOTHING;"

2. Start the API:

   dotnet run --project RotoMonsterTwitter.API

3. In another terminal, push Ken's sample through it
   (swap 5xxx for the port printed on startup, and point at
   wherever tweets.json is saved):

   curl -X POST http://localhost:5xxx/api/tweets/IngestJson/1 \
        -H "Content-Type: application/json" \
        --data-binary @~/Downloads/tweets.json

4. Read it back:

   curl -X POST http://localhost:5xxx/api/tweets/GetTweets \
        -H "Content-Type: application/json" \
        -d '{"sportId":1,"maxResults":3}'

5. Run step 3 again - NewTweets should be 0 the second time,
   which is the dedupe working.
==================================================================
MSGEOF
