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

        var media = new List<TweetMedia>();
        var mediaToken = token["extendedEntities"]?["media"];

        if (mediaToken != null)
        {
            short order = 0;
            foreach (var m in mediaToken)
            {
                var url = m["media_url_https"]?.ToString();
                if (string.IsNullOrEmpty(url)) continue;

                media.Add(new TweetMedia
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
