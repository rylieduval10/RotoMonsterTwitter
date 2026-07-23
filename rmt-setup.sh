#!/usr/bin/env bash
#
# RotoMonsterTwitter - writes the model/service/controller layer.
# Run from the solution root (the folder containing RotoMonsterTwitter.sln).
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing RotoMonsterTwitter.sln" >&2
  exit 1
fi

echo "Creating directories..."
mkdir -p RotoMonsterTwitter.Model/Requests \
         RotoMonsterTwitter.Model/Results \
         RotoMonsterTwitter.Model/Configuration \
         RotoMonsterTwitter.Model/Services \
         RotoMonsterTwitter.Model/Entities \
         RotoMonsterTwitter.Model/Data \
         RotoMonsterTwitter.API/Controllers

# ---------------------------------------------------------------- gitignore
if [ ! -f .gitignore ]; then
cat > .gitignore <<'CSEOF'
bin/
obj/
.vs/
.vscode/
*.user
*.suo
CSEOF
fi

# ---------------------------------------------------------------- entities
echo "Writing entities..."

cat > RotoMonsterTwitter.Model/Entities/TweetUser.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetUser
{
    public long Id { get; set; }
    public string TwitterUserId { get; set; } = "";
    public string ScreenUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string ImageUrl { get; set; } = "";

    public bool IsVerified { get; set; }
    public bool IsBlueVerified { get; set; }
    public string? VerifiedType { get; set; }

    public DateTime? LastSeenAt { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TweetImage.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetImage
{
    public string TweetId { get; set; } = "";
    public short DisplayOrder { get; set; }

    /// <summary>Photo url, or the poster thumbnail for a video.</summary>
    public string ImageUrl { get; set; } = "";

    /// <summary>photo, video, or animated_gif.</summary>
    public string MediaType { get; set; } = "photo";

    /// <summary>Highest-bitrate mp4 for video/gif media; null for photos.</summary>
    public string? VideoUrl { get; set; }

    public int? DurationMillis { get; set; }

    public Tweet? Tweet { get; set; }
}
CSEOF

# ---------------------------------------------------------------- dbcontext
echo "Writing DbContext..."

cat > RotoMonsterTwitter.Model/Data/TwitterDbContext.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Data;

public class TwitterDbContext : DbContext
{
    public TwitterDbContext(DbContextOptions<TwitterDbContext> options)
        : base(options) { }

    public DbSet<Tweet> Tweets => Set<Tweet>();
    public DbSet<TweetImage> TweetImages => Set<TweetImage>();
    public DbSet<TweetUser> TweetUsers => Set<TweetUser>();
    public DbSet<TwitterList> TwitterLists => Set<TwitterList>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Tweet>(e =>
        {
            e.ToTable("Tweets");
            e.HasKey(x => x.TweetId);

            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();
            e.Property(x => x.TwitterUserId).HasMaxLength(50).IsRequired();
            e.Property(x => x.SportId).IsRequired();
            e.Property(x => x.CreatedDate).IsRequired();
            e.Property(x => x.Text).IsRequired();
            e.Property(x => x.RetweetUserScreenName).HasMaxLength(100);
            e.Property(x => x.SourceTweetId).HasMaxLength(50);
            e.Property(x => x.SourceTweetUserScreenName).HasMaxLength(100);

            e.HasIndex(x => x.CreatedDate);
            e.HasIndex(x => new { x.SportId, x.CreatedDate });
            e.HasIndex(x => x.TwitterUserId);

            e.HasOne(x => x.TweetUser)
             .WithMany()
             .HasForeignKey(x => x.TwitterUserId)
             .HasPrincipalKey(x => x.TwitterUserId)
             .OnDelete(DeleteBehavior.Restrict);

            e.HasMany(x => x.Images)
             .WithOne(x => x.Tweet!)
             .HasForeignKey(x => x.TweetId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TweetImage>(e =>
        {
            e.ToTable("TweetImages");
            e.HasKey(x => new { x.TweetId, x.DisplayOrder });
            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();
            e.Property(x => x.ImageUrl).HasMaxLength(500).IsRequired();
            e.Property(x => x.MediaType).HasMaxLength(20).IsRequired();
            e.Property(x => x.VideoUrl).HasMaxLength(500);
        });

        b.Entity<TweetUser>(e =>
        {
            e.ToTable("TweetUsers");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedOnAdd();
            e.Property(x => x.TwitterUserId).HasMaxLength(50).IsRequired();
            e.Property(x => x.ScreenUsername).HasMaxLength(100).IsRequired();
            e.Property(x => x.DisplayName).HasMaxLength(100).IsRequired();
            e.Property(x => x.ImageUrl).HasMaxLength(200);
            e.Property(x => x.VerifiedType).HasMaxLength(50);

            e.HasIndex(x => x.TwitterUserId).IsUnique();
            e.HasIndex(x => x.ScreenUsername).IsUnique();
        });

        b.Entity<TwitterList>(e =>
        {
            e.ToTable("TwitterLists");
            e.HasKey(x => x.ListId);
            e.Property(x => x.ListId).ValueGeneratedNever();
            e.Property(x => x.Name).HasMaxLength(200);

            e.HasIndex(x => x.SportId);
        });
    }
}
CSEOF

# ---------------------------------------------------------------- config
echo "Writing configuration..."

cat > RotoMonsterTwitter.Model/Configuration/TwitterApiOptions.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Configuration;

public class TwitterApiOptions
{
    public const string SectionName = "TwitterApi";

    public string ApiKey { get; set; } = "";
    public string BaseUrl { get; set; } = "https://api.twitterapi.io";
    public string UserAgent { get; set; } = "RotoMonsterTwitter/1.0";
    public int MaxPagesPerFetch { get; set; } = 20;
}
CSEOF

# ---------------------------------------------------------------- requests
echo "Writing requests..."

cat > RotoMonsterTwitter.Model/Requests/GetTweetsRequest.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Requests;

public class GetTweetsRequest
{
    public int? SportId { get; set; }
    public string? ScreenUsername { get; set; }
    public DateTime? CreatedOnOrAfter { get; set; }
    public DateTime? CreatedOnOrBefore { get; set; }
    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 100;
}
CSEOF

cat > RotoMonsterTwitter.Model/Requests/DeleteTweetsRequest.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Requests;

public class DeleteTweetsRequest
{
    public List<string>? TweetIds { get; set; }
    public DateTime? CreatedBefore { get; set; }
    public int? SportId { get; set; }
}
CSEOF

# ---------------------------------------------------------------- results
echo "Writing results..."

cat > RotoMonsterTwitter.Model/Results/BaseResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class BaseResult
{
    public bool Success { get; set; } = true;
    public string? ErrorMessage { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/TweetResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class TweetResult
{
    public string TweetId { get; set; } = "";
    public int SportId { get; set; }
    public DateTime CreatedDate { get; set; }
    public string Text { get; set; } = "";

    public string TwitterUserId { get; set; } = "";
    public string ScreenUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string ImageUrl { get; set; } = "";
    public bool IsVerified { get; set; }
    public bool IsBlueVerified { get; set; }

    public bool? IsRetweet { get; set; }
    public DateTime? RetweetDate { get; set; }
    public string? RetweetUserScreenName { get; set; }
    public string? SourceTweetId { get; set; }
    public string? SourceTweetUserScreenName { get; set; }

    public int? RetweetCount { get; set; }
    public int? Followers { get; set; }

    public List<TweetMediaResult> Media { get; set; } = new();
}

public class TweetMediaResult
{
    public string ImageUrl { get; set; } = "";
    public string MediaType { get; set; } = "photo";
    public string? VideoUrl { get; set; }
    public int? DurationMillis { get; set; }
    public short DisplayOrder { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/GetTweetsResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class GetTweetsResult : BaseResult
{
    public List<TweetResult> Tweets { get; set; } = new();
    public int TotalCount { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/ReadTweetResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class ReadTweetResult : BaseResult
{
    public TweetResult? Tweet { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/DeleteTweetsResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class DeleteTweetsResult : BaseResult
{
    public int DeletedCount { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/IngestResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class IngestResult : BaseResult
{
    public long ListId { get; set; }
    public int SportId { get; set; }
    public int PagesFetched { get; set; }
    public int TweetsReturned { get; set; }
    public int NewTweets { get; set; }
    public int NewUsers { get; set; }
    public long PreviousSinceUnix { get; set; }
    public long NewSinceUnix { get; set; }
}
CSEOF

# ---------------------------------------------------------------- services
echo "Writing services..."

cat > RotoMonsterTwitter.Model/Services/ParsedTweet.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Services;

public class ParsedTweet
{
    public Tweet Tweet { get; set; } = new();
    public TweetUser User { get; set; } = new();
    public List<TweetImage> Media { get; set; } = new();
}

public class TweetPage
{
    public List<ParsedTweet> Tweets { get; set; } = new();
    public bool HasNextPage { get; set; }
    public string? NextCursor { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/ITwitterApiService.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Services;

public interface ITwitterApiService
{
    Task<string> GetListTweetsRawAsync(long listId, long sinceUnixTimestamp = 0,
        string? cursor = null, CancellationToken ct = default);

    Task<TweetPage> GetListTweetsPageAsync(long listId, long sinceUnixTimestamp = 0,
        string? cursor = null, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TwitterApiService.cs <<'CSEOF'
using System.Globalization;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Services;

public class TwitterApiService : ITwitterApiService
{
    private const string TwitterDateFormat = "ddd MMM dd HH:mm:ss zzzz yyyy";

    private readonly HttpClient _http;
    private readonly TwitterApiOptions _options;

    public TwitterApiService(HttpClient http, IOptions<TwitterApiOptions> options)
    {
        _http = http;
        _options = options.Value;
    }

    public async Task<string> GetListTweetsRawAsync(
        long listId, long sinceUnixTimestamp = 0, string? cursor = null,
        CancellationToken ct = default)
    {
        var url = $"{_options.BaseUrl}/twitter/list/tweets?listId={listId}";

        if (sinceUnixTimestamp > 0)
        {
            url += $"&sinceTime={sinceUnixTimestamp}";
        }

        if (!string.IsNullOrWhiteSpace(cursor))
        {
            url += $"&cursor={Uri.EscapeDataString(cursor)}";
        }

        var response = await _http.GetAsync(url, ct);
        var body = await response.Content.ReadAsStringAsync(ct);

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"twitterapi.io returned {(int)response.StatusCode}: {body}");
        }

        return body;
    }

    public async Task<TweetPage> GetListTweetsPageAsync(
        long listId, long sinceUnixTimestamp = 0, string? cursor = null,
        CancellationToken ct = default)
    {
        var body = await GetListTweetsRawAsync(listId, sinceUnixTimestamp, cursor, ct);
        return ParsePage(body);
    }

    public static TweetPage ParsePage(string json)
    {
        var page = new TweetPage();
        var root = JObject.Parse(json);

        var status = root["status"]?.ToString();
        if (!string.IsNullOrEmpty(status) &&
            !status.Equals("success", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"twitterapi.io status '{status}': {root["msg"]}");
        }

        page.HasNextPage = root["has_next_page"]?.Value<bool>() ?? false;
        page.NextCursor = root["next_cursor"]?.ToString();

        var tweets = root["tweets"];
        if (tweets == null) return page;

        foreach (var token in tweets.Children())
        {
            var parsed = ParseOne(token);
            if (parsed != null) page.Tweets.Add(parsed);
        }

        return page;
    }

    private static ParsedTweet? ParseOne(JToken token)
    {
        var tweetId = token["id"]?.ToString();
        var author = token["author"];
        var twitterUserId = author?["id"]?.ToString();

        if (string.IsNullOrEmpty(tweetId) || string.IsNullOrEmpty(twitterUserId))
        {
            return null;
        }

        var user = new TweetUser
        {
            TwitterUserId = twitterUserId,
            ScreenUsername = author?["userName"]?.ToString() ?? "",
            DisplayName = author?["name"]?.ToString() ?? "",
            ImageUrl = author?["profilePicture"]?.ToString() ?? "",
            IsVerified = author?["isVerified"]?.Value<bool>() ?? false,
            IsBlueVerified = author?["isBlueVerified"]?.Value<bool>() ?? false,
            VerifiedType = author?["verifiedType"]?.ToString(),
            LastSeenAt = DateTime.UtcNow
        };

        var tweet = new Tweet
        {
            TweetId = tweetId,
            TwitterUserId = twitterUserId,
            Text = token["text"]?.ToString() ?? "",
            CreatedDate = ParseTwitterDate(token["createdAt"]?.ToString()),
            DateAdded = DateTime.UtcNow,
            RetweetCount = token["retweetCount"]?.Value<int?>(),
            Followers = author?["followers"]?.Value<int?>()
        };

        // ------------------------------------------------------------------
        // TODO (waiting on Ken): map retweet / quote fields.
        //
        // In the sample response, "retweeted_tweet" was null on all 20 tweets
        // and "quoted_tweet" was populated on 4. Ken's columns
        // (IsRetweet / RetweetDate / RetweetUserScreenName / SourceTweetId /
        // SourceTweetUserScreenName / IsSourceTweet) may refer to either.
        //
        // Once confirmed, it is roughly:
        //   var source = token["retweeted_tweet"] ?? token["quoted_tweet"];
        //   if (source != null && source.Type != JTokenType.Null)
        //   {
        //       tweet.IsRetweet = true;
        //       tweet.SourceTweetId = source["id"]?.ToString();
        //       tweet.SourceTweetUserScreenName =
        //           source["author"]?["userName"]?.ToString();
        //   }
        // ------------------------------------------------------------------

        var media = new List<TweetImage>();
        var mediaToken = token["extendedEntities"]?["media"];

        if (mediaToken != null)
        {
            short order = 0;
            foreach (var m in mediaToken)
            {
                var url = m["media_url_https"]?.ToString();
                if (string.IsNullOrEmpty(url)) continue;

                media.Add(new TweetImage
                {
                    TweetId = tweetId,
                    DisplayOrder = order++,
                    ImageUrl = url,
                    MediaType = m["type"]?.ToString() ?? "photo",
                    VideoUrl = PickBestVideoUrl(m["video_info"]?["variants"]),
                    DurationMillis = m["video_info"]?["duration_millis"]?.Value<int?>()
                });
            }
        }

        return new ParsedTweet { Tweet = tweet, User = user, Media = media };
    }

    /// <summary>
    /// Twitter returns several variants per video: one HLS playlist
    /// (application/x-mpegURL, no bitrate) plus mp4s at various bitrates.
    /// Take the highest-bitrate mp4, since that is directly playable.
    /// </summary>
    private static string? PickBestVideoUrl(JToken? variants)
    {
        if (variants == null) return null;

        string? best = null;
        var bestBitrate = -1;

        foreach (var v in variants)
        {
            var contentType = v["content_type"]?.ToString();
            if (!string.Equals(contentType, "video/mp4", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var bitrate = v["bitrate"]?.Value<int?>() ?? 0;
            if (bitrate > bestBitrate)
            {
                bestBitrate = bitrate;
                best = v["url"]?.ToString();
            }
        }

        return best;
    }

    private static DateTime ParseTwitterDate(string? value)
    {
        if (DateTime.TryParseExact(value, TwitterDateFormat,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal,
                out var parsed))
        {
            return parsed;
        }

        return DateTime.UtcNow;
    }

    public static long ToUnix(DateTime utc) =>
        (long)(utc - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalSeconds;
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/ITweetIngestService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetIngestService
{
    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TweetIngestService.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
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
        var list = await _db.TwitterLists.FirstOrDefaultAsync(l => l.ListId == listId, ct);

        if (list == null)
        {
            return new IngestResult
            {
                Success = false,
                ListId = listId,
                ErrorMessage = $"No list configured with id {listId}. Add a row to TwitterLists first."
            };
        }

        var result = new IngestResult
        {
            ListId = listId,
            SportId = list.SportId,
            PreviousSinceUnix = list.LastFetchedUnix,
            NewSinceUnix = list.LastFetchedUnix
        };

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

cat > RotoMonsterTwitter.Model/Services/ITweetService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetService
{
    Task<GetTweetsResult> GetTweetsAsync(GetTweetsRequest request, CancellationToken ct = default);
    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);
    Task<GetTweetsResult> ReadTweetListAsync(long listId, int maxResults = 100, CancellationToken ct = default);
    Task<DeleteTweetsResult> DeleteTweetsAsync(DeleteTweetsRequest request, CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TweetService.cs <<'CSEOF'
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
            .Include(t => t.Images)
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
            .Include(t => t.Images)
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
        Media = t.Images
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
CSEOF

# ---------------------------------------------------------------- controllers
echo "Writing controller..."

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
}
CSEOF

# ---------------------------------------------------------------- program
echo "Writing Program.cs..."

cat > RotoMonsterTwitter.API/Program.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<TwitterDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("TwitterDb")));

builder.Services.Configure<TwitterApiOptions>(
    builder.Configuration.GetSection(TwitterApiOptions.SectionName));

builder.Services.AddHttpClient<ITwitterApiService, TwitterApiService>((sp, client) =>
{
    var options = sp.GetRequiredService<IOptions<TwitterApiOptions>>().Value;
    client.DefaultRequestHeaders.Add("X-API-Key", options.ApiKey);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddScoped<ITweetService, TweetService>();
builder.Services.AddScoped<ITweetIngestService, TweetIngestService>();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapControllers();

app.MapGet("/health", async (TwitterDbContext db) =>
{
    var canConnect = await db.Database.CanConnectAsync();
    return Results.Ok(new { database = canConnect ? "connected" : "unreachable" });
});

app.Run();
CSEOF

echo ""
echo "Files written. Building..."
echo ""
dotnet build

echo ""
echo "=================================================================="
echo "Done. Next steps:"
echo ""
echo "  dotnet ef migrations add AddMediaTypeAndVerification \\"
echo "      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API"
echo "  dotnet ef database update \\"
echo "      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API"
echo ""
echo "  cd RotoMonsterTwitter.API"
echo "  dotnet user-secrets init"
echo "  dotnet user-secrets set \"TwitterApi:ApiKey\" \"YOUR_KEY\""
echo "  cd .."
echo "=================================================================="
