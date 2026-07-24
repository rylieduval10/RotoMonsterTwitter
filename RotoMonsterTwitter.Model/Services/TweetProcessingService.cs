using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public class TweetProcessingService : ITweetProcessingService
{
    // Confidence by how the name was matched.
    private const decimal FullNameConfidence = 1.00m;
    private const decimal AliasConfidence = 0.85m;
    private const decimal LastNameConfidence = 0.70m;
    private const decimal CommonWordConfidence = 0.35m;

    // Added when the player's own team is also named in the tweet.
    private const decimal TeamContextBoost = 0.15m;

    private readonly TwitterDbContext _db;

    public TweetProcessingService(TwitterDbContext db) => _db = db;

    public async Task<ProcessTweetsResult> GetStatusAsync(CancellationToken ct = default)
        => new()
        {
            RemainingUnprocessed = await _db.Tweets
                .CountAsync(t => t.ProcessedAt == null, ct),
            ActiveKeywords = await _db.TwitterKeywords.CountAsync(k => k.IsActive, ct),
            KeywordMatches = await _db.TweetKeywords.CountAsync(ct),
            PlayerMatches = await _db.TweetPlayers.CountAsync(ct),
            TeamMatches = await _db.TweetTeams.CountAsync(ct),
            ActivePlayers = await _db.TwitterPlayers.CountAsync(p => p.IsActive, ct)
        };

    public async Task<ProcessTweetsResult> ProcessAsync(int batchSize = 500,
        bool reprocessAll = false, CancellationToken ct = default)
    {
        var keywords = await _db.TwitterKeywords
            .Where(k => k.IsActive && k.NormalizedKeyword != "")
            .Select(k => new { k.Id, k.NormalizedKeyword })
            .ToListAsync(ct);

        var players = await _db.TwitterPlayers
            .Where(p => p.IsActive)
            .Include(p => p.Aliases)
            .ToListAsync(ct);

        var teams = await _db.TwitterTeams
            .Where(t => t.IsActive)
            .Include(t => t.Aliases)
            .ToListAsync(ct);

        var result = new ProcessTweetsResult
        {
            ActiveKeywords = keywords.Count,
            ActivePlayers = players.Count
        };

        if (keywords.Count == 0 && players.Count == 0)
        {
            result.Success = false;
            result.ErrorMessage = "Nothing to match against - no keywords and no players.";
            return result;
        }

        var query = _db.Tweets.AsQueryable();

        if (!reprocessAll)
        {
            query = query.Where(t => t.ProcessedAt == null);
        }

        var tweets = await query
            .OrderBy(t => t.CreatedDate)
            .Take(Math.Clamp(batchSize, 1, 5000))
            .Select(t => new { t.TweetId, t.Text, t.SportId })
            .ToListAsync(ct);

        if (tweets.Count == 0) return result;

        var tweetIds = tweets.Select(t => t.TweetId).ToList();

        // Clear previous matches so reprocessing replaces rather than duplicates.
        await _db.TweetKeywords.Where(x => tweetIds.Contains(x.TweetId))
            .ExecuteDeleteAsync(ct);
        await _db.TweetPlayers.Where(x => tweetIds.Contains(x.TweetId))
            .ExecuteDeleteAsync(ct);
        await _db.TweetTeams.Where(x => tweetIds.Contains(x.TweetId))
            .ExecuteDeleteAsync(ct);

        var keywordMatches = new List<TweetKeyword>();
        var playerMatches = new List<TweetPlayer>();
        var teamMatches = new List<TweetTeam>();

        foreach (var tweet in tweets)
        {
            var text = TextNormalizer.NormalizeText(tweet.Text);
            var matchedAnything = false;

            foreach (var keyword in keywords)
            {
                var count = TextNormalizer.CountOccurrences(text, keyword.NormalizedKeyword);
                if (count == 0) continue;

                keywordMatches.Add(new TweetKeyword
                {
                    TweetId = tweet.TweetId,
                    KeywordId = keyword.Id,
                    Occurrences = count
                });

                matchedAnything = true;
            }

            // Teams first, so their ids can disambiguate players below.
            var teamsInTweet = new HashSet<int>();

            foreach (var team in teams.Where(t => t.SportId == tweet.SportId))
            {
                var match = MatchTeam(text, team);
                if (match == null) continue;

                match.TweetId = tweet.TweetId;
                teamMatches.Add(match);
                teamsInTweet.Add(team.TeamId);
                matchedAnything = true;
            }

            foreach (var player in players.Where(p => p.SportId == tweet.SportId))
            {
                var match = MatchPlayer(text, player, teamsInTweet);
                if (match == null) continue;

                match.TweetId = tweet.TweetId;
                playerMatches.Add(match);
                matchedAnything = true;
            }

            if (matchedAnything) result.TweetsWithMatches++;
        }

        if (keywordMatches.Count > 0) _db.TweetKeywords.AddRange(keywordMatches);
        if (playerMatches.Count > 0) _db.TweetPlayers.AddRange(playerMatches);
        if (teamMatches.Count > 0) _db.TweetTeams.AddRange(teamMatches);

        var stamp = DateTime.UtcNow;

        await _db.Tweets
            .Where(t => tweetIds.Contains(t.TweetId))
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.ProcessedAt, stamp), ct);

        await _db.SaveChangesAsync(ct);

        result.TweetsProcessed = tweets.Count;
        result.KeywordMatches = keywordMatches.Count;
        result.PlayerMatches = playerMatches.Count;
        result.TeamMatches = teamMatches.Count;
        result.RemainingUnprocessed = await _db.Tweets
            .CountAsync(t => t.ProcessedAt == null, ct);

        return result;
    }

    /// <summary>
    /// Full name beats an alias beats a surname. A surname that is also an
    /// ordinary English word scores low, and FullNameOnly skips it entirely.
    /// </summary>
    private static TweetPlayer? MatchPlayer(string text, TwitterPlayer player,
        HashSet<int> teamsInTweet)
    {
        var count = TextNormalizer.CountOccurrences(text, player.NormalizedFullName);

        if (count > 0)
        {
            return Build(player, "FullName", FullNameConfidence, count, teamsInTweet);
        }

        foreach (var alias in player.Aliases)
        {
            count = TextNormalizer.CountOccurrences(text, alias.NormalizedAlias);

            if (count > 0)
            {
                return Build(player, "Alias", AliasConfidence, count, teamsInTweet);
            }
        }

        if (player.FullNameOnly) return null;

        count = TextNormalizer.CountOccurrences(text, player.NormalizedLastName);

        if (count == 0) return null;

        var confidence = CommonWords.IsCommonWord(player.NormalizedLastName)
            ? CommonWordConfidence
            : LastNameConfidence;

        return Build(player, "LastName", confidence, count, teamsInTweet);
    }

    private static TweetPlayer Build(TwitterPlayer player, string matchType,
        decimal confidence, int occurrences, HashSet<int> teamsInTweet)
    {
        // A surname is far more likely to be this player if the tweet also
        // names his team - a Hornets writer saying Bridges means Miles.
        if (player.TeamId.HasValue && teamsInTweet.Contains(player.TeamId.Value))
        {
            confidence = Math.Min(1.00m, confidence + TeamContextBoost);
        }

        return new TweetPlayer
        {
            TweetId = "",
            PlayerId = player.PlayerId,
            MatchType = matchType,
            Confidence = confidence,
            Occurrences = occurrences
        };
    }

    private static TweetTeam? MatchTeam(string text, TwitterTeam team)
    {
        var count = TextNormalizer.CountOccurrences(text, team.NormalizedFullName);
        if (count > 0) return TeamMatch(team, "FullName", 1.00m, count);

        count = TextNormalizer.CountOccurrences(text, team.NormalizedName);
        if (count > 0) return TeamMatch(team, "Name", 0.90m, count);

        foreach (var alias in team.Aliases)
        {
            count = TextNormalizer.CountOccurrences(text, alias.NormalizedAlias);
            if (count > 0) return TeamMatch(team, "Alias", 0.85m, count);
        }

        // Abbreviations are three letters and collide with ordinary words,
        // so they are the weakest signal we accept.
        if (!string.IsNullOrEmpty(team.NormalizedAbbreviation))
        {
            count = TextNormalizer.CountOccurrences(text, team.NormalizedAbbreviation);
            if (count > 0) return TeamMatch(team, "Abbreviation", 0.50m, count);
        }

        return null;
    }

    private static TweetTeam TeamMatch(TwitterTeam team, string matchType,
        decimal confidence, int occurrences)
        => new()
        {
            TweetId = "",
            TeamId = team.TeamId,
            MatchType = matchType,
            Confidence = confidence,
            Occurrences = occurrences
        };
}
