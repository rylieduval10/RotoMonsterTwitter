#!/usr/bin/env bash
#
# RotoMonsterTwitter - player/team import and matching.
#
# Adds storage for players, teams and their aliases, an import endpoint Ken
# pushes to, and player/team extraction in the processing pass.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

mkdir -p for-ken

echo "Writing entities..."

cat > RotoMonsterTwitter.Model/Entities/TwitterPlayer.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TwitterPlayer
{
    /// <summary>Basketball Monster's player id. Ken's, not ours.</summary>
    public int PlayerId { get; set; }

    public int SportId { get; set; }

    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";

    public string NormalizedFullName { get; set; } = "";
    public string NormalizedLastName { get; set; } = "";

    public int? TeamId { get; set; }

    /// <summary>
    /// Ken's existing practice: for surnames that are ordinary words (Love,
    /// Green, White) only match when the first name is present too.
    /// </summary>
    public bool FullNameOnly { get; set; }

    public bool IsActive { get; set; } = true;

    public List<TwitterPlayerAlias> Aliases { get; set; } = new();
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TwitterPlayerAlias.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TwitterPlayerAlias
{
    public int Id { get; set; }
    public int PlayerId { get; set; }

    public string Alias { get; set; } = "";
    public string NormalizedAlias { get; set; } = "";

    public TwitterPlayer? Player { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TwitterTeam.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TwitterTeam
{
    public int TeamId { get; set; }
    public int SportId { get; set; }

    public string City { get; set; } = "";
    public string Name { get; set; } = "";
    public string Abbreviation { get; set; } = "";

    public string NormalizedFullName { get; set; } = "";
    public string NormalizedName { get; set; } = "";
    public string NormalizedAbbreviation { get; set; } = "";

    public bool IsActive { get; set; } = true;

    public List<TwitterTeamAlias> Aliases { get; set; } = new();
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TwitterTeamAlias.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TwitterTeamAlias
{
    public int Id { get; set; }
    public int TeamId { get; set; }

    public string Alias { get; set; } = "";
    public string NormalizedAlias { get; set; } = "";

    public TwitterTeam? Team { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TweetPlayer.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetPlayer
{
    public string TweetId { get; set; } = "";
    public int PlayerId { get; set; }

    /// <summary>FullName, Alias or LastName.</summary>
    public string MatchType { get; set; } = "";

    /// <summary>
    /// 1.0 for a first+last hit, lower for a surname on its own, lowest when
    /// that surname is also an ordinary English word. Filter on this.
    /// </summary>
    public decimal Confidence { get; set; }

    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterPlayer? Player { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TweetTeam.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetTeam
{
    public string TweetId { get; set; } = "";
    public int TeamId { get; set; }

    /// <summary>FullName, Name, Alias or Abbreviation.</summary>
    public string MatchType { get; set; } = "";

    public decimal Confidence { get; set; }
    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterTeam? Team { get; set; }
}
CSEOF

echo "Writing import contract..."

cat > RotoMonsterTwitter.Model/Requests/PlayerImportRequest.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Requests;

/// <summary>
/// The whole player and team pool for one sport. Sent complete each time -
/// the API replaces what it has rather than diffing, so the sender never has
/// to track what changed.
/// </summary>
public class PlayerImportRequest
{
    /// <summary>1 = basketball, 2 = baseball.</summary>
    public int SportId { get; set; }

    public List<PlayerImport> Players { get; set; } = new();
    public List<TeamImport> Teams { get; set; } = new();
}

public class PlayerImport
{
    public int PlayerId { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public int? TeamId { get; set; }

    /// <summary>
    /// Set for surnames that are ordinary words - Love, Green, White, Young.
    /// Those will only match when the first name appears too.
    /// </summary>
    public bool FullNameOnly { get; set; }

    public List<string> Aliases { get; set; } = new();
}

public class TeamImport
{
    public int TeamId { get; set; }
    public string City { get; set; } = "";
    public string Name { get; set; } = "";
    public string Abbreviation { get; set; } = "";

    /// <summary>Blazers, Sixers, Cavs - however people actually write it.</summary>
    public List<string> Aliases { get; set; } = new();
}
CSEOF

cat > RotoMonsterTwitter.Model/Results/ImportResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class ImportResult : BaseResult
{
    public int SportId { get; set; }
    public int PlayersImported { get; set; }
    public int TeamsImported { get; set; }
    public int PlayerAliases { get; set; }
    public int TeamAliases { get; set; }

    /// <summary>Rows dropped because they were missing a name or an id.</summary>
    public int Skipped { get; set; }
}
CSEOF

echo "Writing common-word list..."

cat > RotoMonsterTwitter.Model/Services/CommonWords.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Surnames that are also ordinary English words. A tweet saying "some love
/// for Walsh" should not read as a reference to Kevin Love, so a surname-only
/// hit on one of these is recorded at low confidence.
///
/// This is a backstop. Ken can set FullNameOnly per player, which is stronger.
/// </summary>
public static class CommonWords
{
    private static readonly HashSet<string> Words = new(StringComparer.Ordinal)
    {
        "love", "green", "brown", "white", "black", "young", "rose", "wood",
        "smart", "king", "bird", "hart", "fox", "wells", "reed", "bell",
        "little", "sharp", "banks", "rich", "moody", "champagne", "star",
        "day", "may", "june", "march", "will", "mark", "grant", "chase",
        "cash", "coach", "field", "gay", "hall", "hill", "house", "hunt",
        "lamb", "land", "lane", "long", "lord", "man", "mills", "moon",
        "morning", "pace", "page", "park", "price", "rice", "ring", "river",
        "rivers", "sands", "shine", "short", "snow", "stone", "storm",
        "strong", "summer", "swift", "walker", "ward", "waters", "west",
        "wise", "winter", "best", "bright", "case", "close", "cross",
        "dean", "dice", "drew", "east", "fine", "flowers", "free", "frost",
        "gates", "gold", "good", "hope", "just", "key", "knight", "law",
        "light", "mason", "north", "pope", "power", "quick", "rain", "read",
        "real", "roll", "sage", "sale", "salt", "score", "seal", "second",
        "sky", "small", "south", "spring", "steel", "stern", "still",
        "stout", "street", "sun", "true", "wall", "watch", "well", "wild",
        "win", "wolf", "worth"
    };

    public static bool IsCommonWord(string normalizedWord)
        => Words.Contains(normalizedWord);
}
CSEOF

echo "Writing import service..."

cat > RotoMonsterTwitter.Model/Services/IPlayerImportService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface IPlayerImportService
{
    Task<ImportResult> ImportAsync(PlayerImportRequest request,
        CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/PlayerImportService.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Replaces the player and team pool for one sport. Whole-set replacement
/// rather than a diff, so the sender doesn't have to track changes and a
/// retired player disappears without anyone having to say so.
/// </summary>
public class PlayerImportService : IPlayerImportService
{
    private readonly TwitterDbContext _db;

    public PlayerImportService(TwitterDbContext db) => _db = db;

    public async Task<ImportResult> ImportAsync(PlayerImportRequest request,
        CancellationToken ct = default)
    {
        var result = new ImportResult { SportId = request.SportId };

        if (request.SportId <= 0)
        {
            result.Success = false;
            result.ErrorMessage = "SportId is required.";
            return result;
        }

        if (request.Players.Count == 0 && request.Teams.Count == 0)
        {
            result.Success = false;
            result.ErrorMessage = "Nothing to import. Refusing to wipe the pool.";
            return result;
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(ct);

        // Teams first - players reference them.
        if (request.Teams.Count > 0)
        {
            await _db.TwitterTeams
                .Where(t => t.SportId == request.SportId)
                .ExecuteDeleteAsync(ct);

            foreach (var incoming in request.Teams)
            {
                if (incoming.TeamId <= 0 || string.IsNullOrWhiteSpace(incoming.Name))
                {
                    result.Skipped++;
                    continue;
                }

                var team = new TwitterTeam
                {
                    TeamId = incoming.TeamId,
                    SportId = request.SportId,
                    City = incoming.City,
                    Name = incoming.Name,
                    Abbreviation = incoming.Abbreviation,
                    NormalizedFullName = TextNormalizer.NormalizeTerm(
                        $"{incoming.City} {incoming.Name}"),
                    NormalizedName = TextNormalizer.NormalizeTerm(incoming.Name),
                    NormalizedAbbreviation = TextNormalizer.NormalizeTerm(
                        incoming.Abbreviation)
                };

                foreach (var alias in incoming.Aliases.Distinct())
                {
                    var normalized = TextNormalizer.NormalizeTerm(alias);
                    if (string.IsNullOrEmpty(normalized)) continue;

                    team.Aliases.Add(new TwitterTeamAlias
                    {
                        Alias = alias,
                        NormalizedAlias = normalized
                    });
                }

                _db.TwitterTeams.Add(team);
                result.TeamsImported++;
                result.TeamAliases += team.Aliases.Count;
            }
        }

        if (request.Players.Count > 0)
        {
            await _db.TwitterPlayers
                .Where(p => p.SportId == request.SportId)
                .ExecuteDeleteAsync(ct);

            foreach (var incoming in request.Players)
            {
                if (incoming.PlayerId <= 0 || string.IsNullOrWhiteSpace(incoming.LastName))
                {
                    result.Skipped++;
                    continue;
                }

                var player = new TwitterPlayer
                {
                    PlayerId = incoming.PlayerId,
                    SportId = request.SportId,
                    FirstName = incoming.FirstName,
                    LastName = incoming.LastName,
                    TeamId = incoming.TeamId,
                    FullNameOnly = incoming.FullNameOnly,
                    NormalizedFullName = TextNormalizer.NormalizeTerm(
                        $"{incoming.FirstName} {incoming.LastName}"),
                    NormalizedLastName = TextNormalizer.NormalizeTerm(incoming.LastName)
                };

                foreach (var alias in incoming.Aliases.Distinct())
                {
                    var normalized = TextNormalizer.NormalizeTerm(alias);
                    if (string.IsNullOrEmpty(normalized)) continue;

                    player.Aliases.Add(new TwitterPlayerAlias
                    {
                        Alias = alias,
                        NormalizedAlias = normalized
                    });
                }

                _db.TwitterPlayers.Add(player);
                result.PlayersImported++;
                result.PlayerAliases += player.Aliases.Count;
            }
        }

        await _db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);

        return result;
    }
}
CSEOF

echo "Extending the processing service..."

cat > RotoMonsterTwitter.Model/Services/TweetProcessingService.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Results;

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
CSEOF

echo "Updating result and controllers..."

cat > RotoMonsterTwitter.Model/Results/ProcessTweetsResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class ProcessTweetsResult : BaseResult
{
    public int TweetsProcessed { get; set; }
    public int TweetsWithMatches { get; set; }

    public int KeywordMatches { get; set; }
    public int PlayerMatches { get; set; }
    public int TeamMatches { get; set; }

    public int RemainingUnprocessed { get; set; }
    public int ActiveKeywords { get; set; }
    public int ActivePlayers { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.API/Controllers/ImportController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/import")]
public class ImportController : ControllerBase
{
    private readonly IPlayerImportService _import;

    public ImportController(IPlayerImportService import) => _import = import;

    /// <summary>
    /// Replace the player and team pool for a sport. Send the complete set;
    /// anything missing from it is dropped.
    /// </summary>
    [HttpPost("players")]
    public async Task<IActionResult> Players([FromBody] PlayerImportRequest request,
        CancellationToken ct)
        => Ok(await _import.ImportAsync(request, ct));
}
CSEOF

python3 - <<'PYEOF'
import pathlib

p = pathlib.Path("RotoMonsterTwitter.Model/Data/TwitterDbContext.cs")
text = p.read_text()

if "TwitterPlayer" not in text:
    text = text.replace(
        "    public DbSet<TweetKeyword> TweetKeywords => Set<TweetKeyword>();",
        "    public DbSet<TweetKeyword> TweetKeywords => Set<TweetKeyword>();\n"
        "    public DbSet<TwitterPlayer> TwitterPlayers => Set<TwitterPlayer>();\n"
        "    public DbSet<TwitterPlayerAlias> TwitterPlayerAliases => Set<TwitterPlayerAlias>();\n"
        "    public DbSet<TwitterTeam> TwitterTeams => Set<TwitterTeam>();\n"
        "    public DbSet<TwitterTeamAlias> TwitterTeamAliases => Set<TwitterTeamAlias>();\n"
        "    public DbSet<TweetPlayer> TweetPlayers => Set<TweetPlayer>();\n"
        "    public DbSet<TweetTeam> TweetTeams => Set<TweetTeam>();")

    text = text.replace(
        "        b.Entity<TwitterList>(e =>",
        """        b.Entity<TwitterPlayer>(e =>
        {
            e.ToTable("TwitterPlayers");
            e.HasKey(x => x.PlayerId);
            e.Property(x => x.PlayerId).ValueGeneratedNever();
            e.Property(x => x.FirstName).HasMaxLength(100);
            e.Property(x => x.LastName).HasMaxLength(100).IsRequired();
            e.Property(x => x.NormalizedFullName).HasMaxLength(200);
            e.Property(x => x.NormalizedLastName).HasMaxLength(100);

            e.HasIndex(x => x.SportId);
            e.HasIndex(x => x.NormalizedLastName);
            e.HasIndex(x => x.TeamId);

            e.HasMany(x => x.Aliases)
             .WithOne(x => x.Player!)
             .HasForeignKey(x => x.PlayerId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TwitterPlayerAlias>(e =>
        {
            e.ToTable("TwitterPlayerAliases");
            e.HasKey(x => x.Id);
            e.Property(x => x.Alias).HasMaxLength(150).IsRequired();
            e.Property(x => x.NormalizedAlias).HasMaxLength(150).IsRequired();

            e.HasIndex(x => x.NormalizedAlias);
        });

        b.Entity<TwitterTeam>(e =>
        {
            e.ToTable("TwitterTeams");
            e.HasKey(x => x.TeamId);
            e.Property(x => x.TeamId).ValueGeneratedNever();
            e.Property(x => x.City).HasMaxLength(100);
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.Abbreviation).HasMaxLength(10);
            e.Property(x => x.NormalizedFullName).HasMaxLength(200);
            e.Property(x => x.NormalizedName).HasMaxLength(100);
            e.Property(x => x.NormalizedAbbreviation).HasMaxLength(10);

            e.HasIndex(x => x.SportId);

            e.HasMany(x => x.Aliases)
             .WithOne(x => x.Team!)
             .HasForeignKey(x => x.TeamId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TwitterTeamAlias>(e =>
        {
            e.ToTable("TwitterTeamAliases");
            e.HasKey(x => x.Id);
            e.Property(x => x.Alias).HasMaxLength(150).IsRequired();
            e.Property(x => x.NormalizedAlias).HasMaxLength(150).IsRequired();

            e.HasIndex(x => x.NormalizedAlias);
        });

        b.Entity<TweetPlayer>(e =>
        {
            e.ToTable("TweetPlayers");
            e.HasKey(x => new { x.TweetId, x.PlayerId });
            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();
            e.Property(x => x.MatchType).HasMaxLength(20).IsRequired();
            e.Property(x => x.Confidence).HasPrecision(3, 2);

            e.HasIndex(x => x.PlayerId);
            e.HasIndex(x => x.Confidence);

            e.HasOne(x => x.Tweet)
             .WithMany()
             .HasForeignKey(x => x.TweetId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(x => x.Player)
             .WithMany()
             .HasForeignKey(x => x.PlayerId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TweetTeam>(e =>
        {
            e.ToTable("TweetTeams");
            e.HasKey(x => new { x.TweetId, x.TeamId });
            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();
            e.Property(x => x.MatchType).HasMaxLength(20).IsRequired();
            e.Property(x => x.Confidence).HasPrecision(3, 2);

            e.HasIndex(x => x.TeamId);

            e.HasOne(x => x.Tweet)
             .WithMany()
             .HasForeignKey(x => x.TweetId)
             .OnDelete(DeleteBehavior.Cascade);

            e.HasOne(x => x.Team)
             .WithMany()
             .HasForeignKey(x => x.TeamId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TwitterList>(e =>""")

    p.write_text(text)
    print("  patched TwitterDbContext.cs")

p = pathlib.Path("RotoMonsterTwitter.API/Program.cs")
text = p.read_text()

if "IPlayerImportService" not in text:
    text = text.replace(
        "builder.Services.AddScoped<ITweetProcessingService, TweetProcessingService>();",
        "builder.Services.AddScoped<ITweetProcessingService, TweetProcessingService>();\n"
        "builder.Services.AddScoped<IPlayerImportService, PlayerImportService>();")
    p.write_text(text)
    print("  patched Program.cs")
PYEOF

echo "Writing the class for Ken..."

cat > for-ken/RotoMonsterTwitterImport.cs <<'CSEOF'
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace SharedCS
{
    /// <summary>
    /// Builds the player and team payload for the RotoMonsterTwitter API.
    ///
    /// Fill it in, call RenderAsJson, and POST the result to:
    ///     https://twitter.rotomonster.com/api/import/players
    /// with header:
    ///     X-API-Key: your key
    ///
    /// Send the complete pool every time. The API replaces what it has for
    /// that sport rather than merging, so retired players drop off on their
    /// own and nothing has to track what changed.
    ///
    /// Example:
    ///     var import = new TwitterImport { SportId = 1 };
    ///
    ///     import.Players.Add(new TwitterImportPlayer
    ///     {
    ///         PlayerId = 1234,
    ///         FirstName = "Kevin",
    ///         LastName  = "Love",
    ///         TeamId    = 12,
    ///         FullNameOnly = true          // surname is an ordinary word
    ///     });
    ///
    ///     import.Teams.Add(new TwitterImportTeam
    ///     {
    ///         TeamId = 12,
    ///         City = "Portland",
    ///         Name = "Trail Blazers",
    ///         Abbreviation = "POR",
    ///         Aliases = { "Blazers", "Rip City" }
    ///     });
    ///
    ///     string json = import.RenderAsJson();
    /// </summary>
    public class TwitterImport
    {
        /// <summary>1 = basketball, 2 = baseball.</summary>
        public int SportId { get; set; }

        public List<TwitterImportPlayer> Players { get; set; }
            = new List<TwitterImportPlayer>();

        public List<TwitterImportTeam> Teams { get; set; }
            = new List<TwitterImportTeam>();

        private static readonly JsonSerializerSettings Settings =
            new JsonSerializerSettings
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
                NullValueHandling = NullValueHandling.Ignore
            };

        public string RenderAsJson()
            => JsonConvert.SerializeObject(this, Settings);

        public string RenderAsJson(bool indented)
            => JsonConvert.SerializeObject(this,
                indented ? Formatting.Indented : Formatting.None, Settings);
    }

    public class TwitterImportPlayer
    {
        /// <summary>Basketball Monster's player id.</summary>
        public int PlayerId { get; set; }

        public string FirstName { get; set; } = "";
        public string LastName { get; set; } = "";

        /// <summary>Matches TeamId on one of the teams in the same payload.</summary>
        public int? TeamId { get; set; }

        /// <summary>
        /// Set this for surnames that are ordinary words - Love, Green, White,
        /// Young. Those players will only match when the first name appears in
        /// the tweet as well, which avoids "some love for Walsh" reading as a
        /// reference to Kevin Love.
        /// </summary>
        public bool FullNameOnly { get; set; }

        /// <summary>Nicknames and alternate spellings. Matched on their own.</summary>
        public List<string> Aliases { get; set; } = new List<string>();
    }

    public class TwitterImportTeam
    {
        public int TeamId { get; set; }

        public string City { get; set; } = "";
        public string Name { get; set; } = "";
        public string Abbreviation { get; set; } = "";

        /// <summary>
        /// However people actually write it - Blazers, Sixers, Cavs. Worth
        /// filling in: team mentions are what break ties between players who
        /// share a surname.
        /// </summary>
        public List<string> Aliases { get; set; } = new List<string>();
    }
}
CSEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Migration:

  dotnet ef migrations add AddPlayersAndTeams \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API
  dotnet ef database update \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API

The file to send Ken is at:

  for-ken/RotoMonsterTwitterImport.cs

He drops it into SharedCS, fills in players and teams, calls
RenderAsJson, and POSTs to /api/import/players with the API key.

To test locally before he sends anything real, post a small payload
yourself:

  curl -X POST http://localhost:5080/api/import/players \
    -H "Content-Type: application/json" \
    -d '{"sportId":1,"players":[
          {"playerId":1,"firstName":"Kevin","lastName":"Love","fullNameOnly":true},
          {"playerId":2,"firstName":"Miles","lastName":"Bridges","teamId":30},
          {"playerId":3,"firstName":"Mikal","lastName":"Bridges","teamId":20}],
        "teams":[
          {"teamId":30,"city":"Charlotte","name":"Hornets","abbreviation":"CHA"},
          {"teamId":20,"city":"New York","name":"Knicks","abbreviation":"NYK"}]}'

  curl -X POST "http://localhost:5080/api/processing/run?reprocessAll=true"
==================================================================
MSGEOF
