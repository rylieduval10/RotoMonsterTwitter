#!/usr/bin/env bash
#
# RotoMonsterTwitter - tweet processing: keyword extraction.
#
# Adds TwitterKeywords + TweetKeywords, a text normalizer, a matcher, and a
# processing pass that can run over unprocessed tweets or rescan everything.
#
# Player matching comes later, once Ken sends the roster json.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Writing entities..."

cat > RotoMonsterTwitter.Model/Entities/TwitterKeyword.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TwitterKeyword
{
    /// <summary>Ken's own ids, preserved so his existing references still line up.</summary>
    public int Id { get; set; }

    /// <summary>As Ken wrote it. Shown in the UI.</summary>
    public string Keyword { get; set; } = "";

    /// <summary>Lowercased, de-accented, punctuation stripped. What matching uses.</summary>
    public string NormalizedKeyword { get; set; } = "";

    /// <summary>Injury, Availability, Transaction, Discipline, Personal, TeamActivity.</summary>
    public string Category { get; set; } = "Injury";

    /// <summary>
    /// How much to trust a hit. Ordinary English words that happen to be on the
    /// list (start, bench, five, face) sit at 0.3 so they can be filtered out.
    /// </summary>
    public decimal Weight { get; set; } = 1.0m;

    public bool IsActive { get; set; } = true;
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/TweetKeyword.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetKeyword
{
    public string TweetId { get; set; } = "";
    public int KeywordId { get; set; }

    /// <summary>How many times it appeared in the tweet.</summary>
    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterKeyword? Keyword { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Entities/Tweet.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class Tweet
{
    public string TweetId { get; set; } = "";
    public string TwitterUserId { get; set; } = "";

    public int SportId { get; set; }

    public DateTime CreatedDate { get; set; }
    public DateTime? RetweetDate { get; set; }
    public DateTime? DateAdded { get; set; }

    /// <summary>Null means it hasn't been through keyword extraction yet.</summary>
    public DateTime? ProcessedAt { get; set; }

    public bool? IsRetweet { get; set; }
    public bool? IsSourceTweet { get; set; }

    public string? RetweetUserScreenName { get; set; }

    public string Text { get; set; } = "";

    public int? RetweetCount { get; set; }
    public int? Followers { get; set; }

    public string? SourceTweetId { get; set; }
    public string? SourceTweetUserScreenName { get; set; }

    public TweetUser? TweetUser { get; set; }
    public List<TweetMedia> Media { get; set; } = new();
    public List<TweetKeyword> Keywords { get; set; } = new();
}
CSEOF

echo "Writing text normalizer..."

cat > RotoMonsterTwitter.Model/Services/TextNormalizer.cs <<'CSEOF'
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Turns tweet text into a form that can be matched against reliably.
///
/// Tweets are messy in ways that quietly break naive matching: curly
/// apostrophes rather than straight ones, accented names, @mentions and
/// hashtags that contain ordinary words, and t.co links on the end of
/// everything. This flattens all of that.
///
/// Output is space-padded, so a caller can test " keyword " and get whole-word
/// matching for single words and phrases alike without any regex.
/// </summary>
public static class TextNormalizer
{
    private static readonly Regex UrlPattern =
        new(@"https?://\S+", RegexOptions.Compiled);

    private static readonly Regex MentionPattern =
        new(@"(?<![\w])@\w+", RegexOptions.Compiled);

    private static readonly Regex NonAlphanumeric =
        new(@"[^a-z0-9]+", RegexOptions.Compiled);

    private static readonly Regex Whitespace =
        new(@"\s+", RegexOptions.Compiled);

    /// <summary>Normalize tweet text. Returns a space-padded token string.</summary>
    public static string NormalizeText(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return " ";

        var value = text;

        // Links and mentions carry words that aren't really in the tweet -
        // "@King_Cutty1" should not count as a reference to a player named King.
        value = UrlPattern.Replace(value, " ");
        value = MentionPattern.Replace(value, " ");

        // Hashtags keep their word: #Saints should still read as saints.
        value = value.Replace("#", " ");

        return " " + Flatten(value) + " ";
    }

    /// <summary>Normalize a keyword or name. Not padded.</summary>
    public static string NormalizeTerm(string? term)
        => string.IsNullOrWhiteSpace(term) ? "" : Flatten(term);

    private static string Flatten(string value)
    {
        value = value.ToLowerInvariant();

        // Apostrophes vanish rather than becoming spaces, so "won't" reads as
        // "wont" - which is how Ken has it in his keyword list.
        value = value.Replace("'", "").Replace("\u2019", "").Replace("\u02BC", "");

        value = StripDiacritics(value);
        value = NonAlphanumeric.Replace(value, " ");
        value = Whitespace.Replace(value, " ");

        return value.Trim();
    }

    /// <summary>Jokic and Jokić should be the same word.</summary>
    private static string StripDiacritics(string value)
    {
        var decomposed = value.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(c);
            }
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    /// <summary>Count non-overlapping occurrences of a normalized term.</summary>
    public static int CountOccurrences(string paddedText, string normalizedTerm)
    {
        if (string.IsNullOrEmpty(normalizedTerm)) return 0;

        var needle = " " + normalizedTerm + " ";
        var count = 0;
        var index = 0;

        while (true)
        {
            index = paddedText.IndexOf(needle, index, StringComparison.Ordinal);
            if (index < 0) break;

            count++;

            // Step back one so " a b " can match twice in " a b a b ".
            index += needle.Length - 1;
        }

        return count;
    }
}
CSEOF

echo "Writing processing service..."

cat > RotoMonsterTwitter.Model/Results/ProcessTweetsResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class ProcessTweetsResult : BaseResult
{
    public int TweetsProcessed { get; set; }
    public int KeywordMatches { get; set; }
    public int TweetsWithMatches { get; set; }
    public int RemainingUnprocessed { get; set; }
    public int ActiveKeywords { get; set; }
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/ITweetProcessingService.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetProcessingService
{
    /// <summary>
    /// Extract keywords from stored tweets. By default only touches tweets that
    /// haven't been processed; reprocessAll rescans everything, which is what
    /// you want after adding keywords.
    /// </summary>
    Task<ProcessTweetsResult> ProcessAsync(int batchSize = 500,
        bool reprocessAll = false, CancellationToken ct = default);

    Task<ProcessTweetsResult> GetStatusAsync(CancellationToken ct = default);
}
CSEOF

cat > RotoMonsterTwitter.Model/Services/TweetProcessingService.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public class TweetProcessingService : ITweetProcessingService
{
    private readonly TwitterDbContext _db;

    public TweetProcessingService(TwitterDbContext db) => _db = db;

    public async Task<ProcessTweetsResult> GetStatusAsync(CancellationToken ct = default)
        => new()
        {
            RemainingUnprocessed = await _db.Tweets
                .CountAsync(t => t.ProcessedAt == null, ct),
            ActiveKeywords = await _db.TwitterKeywords
                .CountAsync(k => k.IsActive, ct),
            KeywordMatches = await _db.TweetKeywords.CountAsync(ct)
        };

    public async Task<ProcessTweetsResult> ProcessAsync(int batchSize = 500,
        bool reprocessAll = false, CancellationToken ct = default)
    {
        var keywords = await _db.TwitterKeywords
            .Where(k => k.IsActive && k.NormalizedKeyword != "")
            .Select(k => new { k.Id, k.NormalizedKeyword })
            .ToListAsync(ct);

        var result = new ProcessTweetsResult { ActiveKeywords = keywords.Count };

        if (keywords.Count == 0)
        {
            result.Success = false;
            result.ErrorMessage = "No active keywords. Seed TwitterKeywords first.";
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
            .Select(t => new { t.TweetId, t.Text })
            .ToListAsync(ct);

        if (tweets.Count == 0)
        {
            result.RemainingUnprocessed = 0;
            return result;
        }

        var tweetIds = tweets.Select(t => t.TweetId).ToList();

        // Clear old matches for these tweets so reprocessing replaces rather
        // than duplicates.
        await _db.TweetKeywords
            .Where(tk => tweetIds.Contains(tk.TweetId))
            .ExecuteDeleteAsync(ct);

        var matches = new List<TweetKeyword>();

        foreach (var tweet in tweets)
        {
            var normalized = TextNormalizer.NormalizeText(tweet.Text);
            var found = 0;

            foreach (var keyword in keywords)
            {
                var count = TextNormalizer.CountOccurrences(
                    normalized, keyword.NormalizedKeyword);

                if (count == 0) continue;

                matches.Add(new TweetKeyword
                {
                    TweetId = tweet.TweetId,
                    KeywordId = keyword.Id,
                    Occurrences = count
                });

                found++;
            }

            if (found > 0) result.TweetsWithMatches++;
        }

        if (matches.Count > 0)
        {
            _db.TweetKeywords.AddRange(matches);
        }

        var stamp = DateTime.UtcNow;

        await _db.Tweets
            .Where(t => tweetIds.Contains(t.TweetId))
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.ProcessedAt, stamp), ct);

        await _db.SaveChangesAsync(ct);

        result.TweetsProcessed = tweets.Count;
        result.KeywordMatches = matches.Count;
        result.RemainingUnprocessed = await _db.Tweets
            .CountAsync(t => t.ProcessedAt == null, ct);

        return result;
    }
}
CSEOF

echo "Writing controllers..."

cat > RotoMonsterTwitter.API/Controllers/ProcessingController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/processing")]
public class ProcessingController : ControllerBase
{
    private readonly ITweetProcessingService _processing;

    public ProcessingController(ITweetProcessingService processing)
        => _processing = processing;

    /// <summary>How much is left to process, and how many matches exist.</summary>
    [HttpGet("status")]
    public async Task<IActionResult> Status(CancellationToken ct)
        => Ok(await _processing.GetStatusAsync(ct));

    /// <summary>
    /// Process unprocessed tweets. Pass reprocessAll=true to rescan everything,
    /// which is what you want after changing the keyword list.
    /// </summary>
    [HttpPost("run")]
    public async Task<IActionResult> Run([FromQuery] int batchSize = 500,
        [FromQuery] bool reprocessAll = false, CancellationToken ct = default)
        => Ok(await _processing.ProcessAsync(batchSize, reprocessAll, ct));
}
CSEOF

cat > RotoMonsterTwitter.API/Controllers/KeywordsController.cs <<'CSEOF'
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/keywords")]
public class KeywordsController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public KeywordsController(TwitterDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? category,
        CancellationToken ct = default)
    {
        var query = _db.TwitterKeywords.AsQueryable();

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.Where(k => k.Category.ToLower() == category.ToLower());
        }

        return Ok(await query.OrderBy(k => k.Id).ToListAsync(ct));
    }

    /// <summary>
    /// Add or update a keyword. NormalizedKeyword is derived here so callers
    /// never have to think about it.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Save([FromBody] TwitterKeyword keyword,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(keyword.Keyword))
        {
            return BadRequest(new { error = "Keyword text is required." });
        }

        keyword.NormalizedKeyword = TextNormalizer.NormalizeTerm(keyword.Keyword);

        if (string.IsNullOrEmpty(keyword.NormalizedKeyword))
        {
            return BadRequest(new { error = "Keyword contains nothing matchable." });
        }

        var existing = keyword.Id > 0
            ? await _db.TwitterKeywords.FirstOrDefaultAsync(k => k.Id == keyword.Id, ct)
            : null;

        if (existing == null)
        {
            if (keyword.Id <= 0)
            {
                var maxId = await _db.TwitterKeywords.MaxAsync(k => (int?)k.Id, ct) ?? 0;
                keyword.Id = maxId + 1;
            }

            _db.TwitterKeywords.Add(keyword);
        }
        else
        {
            existing.Keyword = keyword.Keyword;
            existing.NormalizedKeyword = keyword.NormalizedKeyword;
            existing.Category = keyword.Category;
            existing.Weight = keyword.Weight;
            existing.IsActive = keyword.IsActive;
        }

        await _db.SaveChangesAsync(ct);

        return Ok(await _db.TwitterKeywords.FirstAsync(k => k.Id == keyword.Id, ct));
    }
}
CSEOF

echo "Updating DbContext and Program..."

python3 - <<'PYEOF'
import pathlib

p = pathlib.Path("RotoMonsterTwitter.Model/Data/TwitterDbContext.cs")
text = p.read_text()

if "TwitterKeyword" not in text:
    text = text.replace(
        "    public DbSet<TwitterList> TwitterLists => Set<TwitterList>();",
        "    public DbSet<TwitterList> TwitterLists => Set<TwitterList>();\n"
        "    public DbSet<TwitterKeyword> TwitterKeywords => Set<TwitterKeyword>();\n"
        "    public DbSet<TweetKeyword> TweetKeywords => Set<TweetKeyword>();")

    text = text.replace(
        "            e.HasIndex(x => x.DateAdded);",
        "            e.HasIndex(x => x.DateAdded);\n"
        "            e.HasIndex(x => x.ProcessedAt);")

    text = text.replace(
        "            e.HasMany(x => x.Media)",
        "            e.HasMany(x => x.Keywords)\n"
        "             .WithOne(x => x.Tweet!)\n"
        "             .HasForeignKey(x => x.TweetId)\n"
        "             .OnDelete(DeleteBehavior.Cascade);\n"
        "\n"
        "            e.HasMany(x => x.Media)")

    text = text.replace(
        "        b.Entity<TwitterList>(e =>",
        "        b.Entity<TwitterKeyword>(e =>\n"
        "        {\n"
        "            e.ToTable(\"TwitterKeywords\");\n"
        "            e.HasKey(x => x.Id);\n"
        "            e.Property(x => x.Id).ValueGeneratedNever();\n"
        "            e.Property(x => x.Keyword).HasMaxLength(100).IsRequired();\n"
        "            e.Property(x => x.NormalizedKeyword).HasMaxLength(100).IsRequired();\n"
        "            e.Property(x => x.Category).HasMaxLength(40).IsRequired();\n"
        "            e.Property(x => x.Weight).HasPrecision(3, 2);\n"
        "\n"
        "            e.HasIndex(x => x.NormalizedKeyword);\n"
        "            e.HasIndex(x => x.Category);\n"
        "        });\n"
        "\n"
        "        b.Entity<TweetKeyword>(e =>\n"
        "        {\n"
        "            e.ToTable(\"TweetKeywords\");\n"
        "            e.HasKey(x => new { x.TweetId, x.KeywordId });\n"
        "            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();\n"
        "\n"
        "            e.HasIndex(x => x.KeywordId);\n"
        "\n"
        "            e.HasOne(x => x.Keyword)\n"
        "             .WithMany()\n"
        "             .HasForeignKey(x => x.KeywordId)\n"
        "             .OnDelete(DeleteBehavior.Cascade);\n"
        "        });\n"
        "\n"
        "        b.Entity<TwitterList>(e =>")

    p.write_text(text)
    print("  patched TwitterDbContext.cs")

p = pathlib.Path("RotoMonsterTwitter.API/Program.cs")
text = p.read_text()

if "ITweetProcessingService" not in text:
    text = text.replace(
        "builder.Services.AddScoped<ITweetIngestService, TweetIngestService>();",
        "builder.Services.AddScoped<ITweetIngestService, TweetIngestService>();\n"
        "builder.Services.AddScoped<ITweetProcessingService, TweetProcessingService>();")
    p.write_text(text)
    print("  patched Program.cs")
PYEOF

echo "Writing keyword seed..."

cat > keywords-seed.sql <<'SQLEOF'
-- Ken's TwitterKeywords list. Safe to re-run.
INSERT INTO "TwitterKeywords" ("Id", "Keyword", "NormalizedKeyword", "Category", "Weight", "IsActive") VALUES
(1, 'achilles', 'achilles', 'Injury', 1.0, true),
(2, 'ankle', 'ankle', 'Injury', 1.0, true),
(3, 'available', 'available', 'Availability', 0.6, true),
(5, 'bruise', 'bruise', 'Injury', 1.0, true),
(6, 'bug', 'bug', 'Injury', 0.3, true),
(7, 'calf', 'calf', 'Injury', 1.0, true),
(8, 'chest', 'chest', 'Injury', 0.6, true),
(9, 'cleared to play', 'cleared to play', 'Availability', 1.0, true),
(10, 'concussion', 'concussion', 'Injury', 1.0, true),
(11, 'day to day', 'day to day', 'Availability', 1.0, true),
(12, 'doubtful', 'doubtful', 'Availability', 1.0, true),
(13, 'elbow', 'elbow', 'Injury', 1.0, true),
(14, 'expected to play', 'expected to play', 'Availability', 1.0, true),
(15, 'eye', 'eye', 'Injury', 0.3, true),
(16, 'fatigue', 'fatigue', 'Injury', 1.0, true),
(17, 'finger', 'finger', 'Injury', 1.0, true),
(18, 'food poisoning', 'food poisoning', 'Injury', 1.0, true),
(19, 'foot', 'foot', 'Injury', 0.6, true),
(22, 'going to start', 'going to start', 'Availability', 1.0, true),
(23, 'gtd', 'gtd', 'Availability', 1.0, true),
(24, 'hamstring', 'hamstring', 'Injury', 1.0, true),
(25, 'hip', 'hip', 'Injury', 0.6, true),
(26, 'illness', 'illness', 'Injury', 1.0, true),
(27, 'inactive', 'inactive', 'Availability', 1.0, true),
(28, 'injury', 'injury', 'Injury', 1.0, true),
(30, 'is out', 'is out', 'Availability', 1.0, true),
(31, 'is starting', 'is starting', 'Availability', 1.0, true),
(33, 'knee', 'knee', 'Injury', 1.0, true),
(34, 'leg', 'leg', 'Injury', 0.6, true),
(35, 'lineup', 'lineup', 'Availability', 0.6, true),
(36, 'lock room', 'lock room', 'TeamActivity', 1.0, true),
(37, 'neck', 'neck', 'Injury', 0.6, true),
(38, 'nose', 'nose', 'Injury', 0.6, true),
(39, 'out indefinitely', 'out indefinitely', 'Availability', 1.0, true),
(40, 'pectoral', 'pectoral', 'Injury', 1.0, true),
(41, 'personal', 'personal', 'Personal', 0.3, true),
(42, 'probable', 'probable', 'Availability', 1.0, true),
(43, 'recovery', 'recovery', 'Injury', 1.0, true),
(44, 'rest', 'rest', 'Availability', 0.3, true),
(45, 'rib', 'rib', 'Injury', 1.0, true),
(46, 'ribs', 'ribs', 'Injury', 1.0, true),
(47, 'shootaround', 'shootaround', 'TeamActivity', 1.0, true),
(48, 'shoulder', 'shoulder', 'Injury', 1.0, true),
(49, 'sick', 'sick', 'Injury', 1.0, true),
(51, 'starters', 'starters', 'Availability', 1.0, true),
(52, 'stomach', 'stomach', 'Injury', 1.0, true),
(53, 'surgery', 'surgery', 'Injury', 1.0, true),
(54, 'suspension', 'suspension', 'Discipline', 1.0, true),
(55, 'thumb', 'thumb', 'Injury', 1.0, true),
(57, 'start tonight', 'start tonight', 'Availability', 1.0, true),
(58, 'will not play', 'will not play', 'Availability', 1.0, true),
(59, 'will not start', 'will not start', 'Availability', 1.0, true),
(60, 'will play', 'will play', 'Availability', 1.0, true),
(61, 'will start', 'will start', 'Availability', 1.0, true),
(62, 'wrist', 'wrist', 'Injury', 1.0, true),
(63, 'dislocated', 'dislocated', 'Injury', 1.0, true),
(64, 'twist', 'twist', 'Injury', 0.6, true),
(65, 'minutes', 'minutes', 'Availability', 0.3, true),
(66, 'plantar fasciitis', 'plantar fasciitis', 'Injury', 1.0, true),
(67, 'sore', 'sore', 'Injury', 1.0, true),
(68, 'hurting', 'hurting', 'Injury', 1.0, true),
(69, 'checks back in', 'checks back in', 'Availability', 1.0, true),
(70, 'targeting', 'targeting', 'Transaction', 0.3, true),
(72, 'month', 'month', 'Availability', 0.3, true),
(73, 'unlikely to play', 'unlikely to play', 'Availability', 1.0, true),
(75, 'suspended', 'suspended', 'Discipline', 1.0, true),
(76, 'traded', 'traded', 'Transaction', 1.0, true),
(77, 'out tonight', 'out tonight', 'Availability', 1.0, true),
(78, 'out tomorrow', 'out tomorrow', 'Availability', 1.0, true),
(79, 'morning shoot', 'morning shoot', 'TeamActivity', 1.0, true),
(80, 'gastroenteritis', 'gastroenteritis', 'Injury', 1.0, true),
(81, 'questionable', 'questionable', 'Availability', 1.0, true),
(82, 'is active', 'is active', 'Availability', 1.0, true),
(83, 'should play', 'should play', 'Availability', 1.0, true),
(84, 'will likely play', 'will likely play', 'Availability', 1.0, true),
(86, 'will not return', 'will not return', 'Availability', 1.0, true),
(87, 'injured', 'injured', 'Injury', 1.0, true),
(88, 'spasms', 'spasms', 'Injury', 1.0, true),
(90, 'good to go', 'good to go', 'Availability', 1.0, true),
(91, 'kneecap', 'kneecap', 'Injury', 1.0, true),
(92, 'patella', 'patella', 'Injury', 1.0, true),
(93, 'is playing', 'is playing', 'Availability', 1.0, true),
(94, 'returned', 'returned', 'Availability', 0.6, true),
(95, 'back with', 'back with', 'Availability', 0.3, true),
(96, 'ready to go', 'ready to go', 'Availability', 1.0, true),
(97, 'ruled out', 'ruled out', 'Availability', 1.0, true),
(98, 'oblique', 'oblique', 'Injury', 1.0, true),
(99, 'muscle', 'muscle', 'Injury', 0.6, true),
(100, 'strained', 'strained', 'Injury', 1.0, true),
(101, 'practiced', 'practiced', 'TeamActivity', 1.0, true),
(102, 'sprain', 'sprain', 'Injury', 1.0, true),
(103, 'rays', 'rays', 'Injury', 0.3, true),
(106, 'lower', 'lower', 'Injury', 0.3, true),
(107, 'upper', 'upper', 'Injury', 0.3, true),
(108, 'toe', 'toe', 'Injury', 1.0, true),
(109, 'sprained', 'sprained', 'Injury', 1.0, true),
(111, 'soreness', 'soreness', 'Injury', 1.0, true),
(112, 'ailing', 'ailing', 'Injury', 1.0, true),
(114, 'ruled', 'ruled', 'Availability', 0.3, true),
(115, 'groin', 'groin', 'Injury', 1.0, true),
(116, 'practice', 'practice', 'TeamActivity', 0.6, true),
(117, 'contusion', 'contusion', 'Injury', 1.0, true),
(118, 'limp', 'limp', 'Injury', 1.0, true),
(119, 'mri', 'mri', 'Injury', 1.0, true),
(120, 'laceration', 'laceration', 'Injury', 1.0, true),
(121, 'chin', 'chin', 'Injury', 0.6, true),
(122, 'lip', 'lip', 'Injury', 0.6, true),
(123, 'trade', 'trade', 'Transaction', 0.6, true),
(124, 'offered', 'offered', 'Transaction', 0.3, true),
(126, 'road trip', 'road trip', 'TeamActivity', 1.0, true),
(127, 'funeral', 'funeral', 'Personal', 1.0, true),
(129, 'go tonight', 'go tonight', 'Availability', 1.0, true),
(130, 'contract', 'contract', 'Transaction', 0.6, true),
(131, 'quad', 'quad', 'Injury', 1.0, true),
(132, 'ejected', 'ejected', 'Discipline', 1.0, true),
(133, 'doctor', 'doctor', 'Injury', 0.6, true),
(134, 'bereavement', 'bereavement', 'Personal', 1.0, true),
(136, 'will sit', 'will sit', 'Availability', 1.0, true),
(137, 'wont play', 'wont play', 'Availability', 1.0, true),
(138, 'listed out', 'listed out', 'Availability', 1.0, true),
(139, 'intent to play', 'intent to play', 'Availability', 1.0, true),
(140, 'not starting', 'not starting', 'Availability', 1.0, true),
(141, 'wont return', 'wont return', 'Availability', 1.0, true),
(142, 'questionable to return', 'questionable to return', 'Availability', 1.0, true),
(143, 'doubtful to return', 'doubtful to return', 'Availability', 1.0, true),
(144, 'probable to return', 'probable to return', 'Availability', 1.0, true),
(145, 'available to return', 'available to return', 'Availability', 1.0, true),
(147, 'out again', 'out again', 'Availability', 1.0, true),
(150, 'out versus', 'out versus', 'Availability', 1.0, true),
(151, 'hopeful to play', 'hopeful to play', 'Availability', 1.0, true),
(152, 'hopes to play', 'hopes to play', 'Availability', 1.0, true),
(153, 'will miss tonight', 'will miss tonight', 'Availability', 1.0, true),
(155, 'plans to play', 'plans to play', 'Availability', 1.0, true),
(156, 'will return tonight', 'will return tonight', 'Availability', 1.0, true),
(158, 'still out', 'still out', 'Availability', 1.0, true),
(160, 'may not go', 'may not go', 'Availability', 1.0, true),
(161, 'questionable to play', 'questionable to play', 'Availability', 1.0, true),
(163, 'is resting', 'is resting', 'Availability', 1.0, true),
(164, 'available to play', 'available to play', 'Availability', 1.0, true),
(165, 'under the weather', 'under the weather', 'Injury', 1.0, true),
(166, 'likely out', 'likely out', 'Availability', 1.0, true),
(167, 'late scratch', 'late scratch', 'Availability', 1.0, true),
(168, 'will be available', 'will be available', 'Availability', 1.0, true),
(169, 'doubtful to play', 'doubtful to play', 'Availability', 1.0, true),
(170, 'locker room', 'locker room', 'TeamActivity', 1.0, true),
(171, 'wont be with', 'wont be with', 'Availability', 1.0, true),
(172, 'paternity', 'paternity', 'Personal', 1.0, true),
(173, 'sit tonight', 'sit tonight', 'Availability', 1.0, true),
(174, 'play tonight', 'play tonight', 'Availability', 1.0, true),
(175, 'play today', 'play today', 'Availability', 1.0, true),
(176, 'sit today', 'sit today', 'Availability', 1.0, true),
(177, 'start today', 'start today', 'Availability', 1.0, true),
(178, 'day-to-day', 'day to day', 'Availability', 1.0, true),
(179, 'not expected to play', 'not expected to play', 'Availability', 1.0, true),
(180, 'will be active', 'will be active', 'Availability', 1.0, true),
(182, 'ready to play', 'ready to play', 'Availability', 1.0, true),
(183, 'hand', 'hand', 'Injury', 0.3, true),
(184, 'not yet ready', 'not yet ready', 'Availability', 1.0, true),
(186, 'back tomorrow', 'back tomorrow', 'Availability', 1.0, true),
(188, 'deal to send', 'deal to send', 'Transaction', 1.0, true),
(189, 'listed as active', 'listed as active', 'Availability', 1.0, true),
(190, 'out vs', 'out vs', 'Availability', 1.0, true),
(191, 'to play tonight', 'to play tonight', 'Availability', 1.0, true),
(192, 'kidney', 'kidney', 'Injury', 1.0, true),
(193, 'walkthrough', 'walkthrough', 'TeamActivity', 1.0, true),
(194, 'playing', 'playing', 'Availability', 0.3, true),
(195, 'will miss', 'will miss', 'Availability', 1.0, true),
(196, 'child', 'child', 'Personal', 0.6, true),
(197, 'starting', 'starting', 'Availability', 0.3, true),
(200, 'start tomorrow', 'start tomorrow', 'Availability', 1.0, true),
(202, 'likely play', 'likely play', 'Availability', 1.0, true),
(204, 'play vs', 'play vs', 'Availability', 1.0, true),
(205, 'tear', 'tear', 'Injury', 0.6, true),
(206, 'will be out', 'will be out', 'Availability', 1.0, true),
(207, 'return date', 'return date', 'Availability', 1.0, true),
(208, 'all out', 'all out', 'Availability', 0.3, true),
(209, 'will warm up', 'will warm up', 'Availability', 1.0, true),
(210, 'injury report', 'injury report', 'Injury', 1.0, true),
(211, 'scratch', 'scratch', 'Availability', 0.6, true),
(212, 'bone', 'bone', 'Injury', 0.6, true),
(213, 'isnt expected to play', 'isnt expected to play', 'Availability', 1.0, true),
(214, 'remains out', 'remains out', 'Availability', 1.0, true),
(217, 'wont be playing', 'wont be playing', 'Availability', 1.0, true),
(218, 'expected to sit', 'expected to sit', 'Availability', 1.0, true),
(219, 'returns tonight', 'returns tonight', 'Availability', 1.0, true),
(220, 'return today', 'return today', 'Availability', 1.0, true),
(221, 'training room', 'training room', 'Injury', 1.0, true),
(222, 'to play today', 'to play today', 'Availability', 1.0, true),
(223, 'mcl', 'mcl', 'Injury', 1.0, true),
(224, 'acl', 'acl', 'Injury', 1.0, true),
(225, 'will return', 'will return', 'Availability', 1.0, true),
(226, 'adductor', 'adductor', 'Injury', 1.0, true),
(227, 'might play', 'might play', 'Availability', 1.0, true),
(228, 'on track', 'on track', 'Availability', 0.6, true),
(229, 'play tomorrow', 'play tomorrow', 'Availability', 1.0, true),
(230, 'brace', 'brace', 'Injury', 1.0, true),
(231, 'right arm', 'right arm', 'Injury', 1.0, true),
(232, 'left arm', 'left arm', 'Injury', 1.0, true),
(233, 'right leg', 'right leg', 'Injury', 1.0, true),
(234, 'left leg', 'left leg', 'Injury', 1.0, true),
(235, 'out today', 'out today', 'Availability', 1.0, true),
(237, 'sending', 'sending', 'Transaction', 0.3, true),
(238, 'pick', 'pick', 'Transaction', 0.3, true),
(239, 'round', 'round', 'Transaction', 0.3, true),
(240, 'flu', 'flu', 'Injury', 1.0, true),
(241, 'gametime', 'gametime', 'Availability', 0.6, true),
(242, 'protocols', 'protocols', 'Injury', 1.0, true),
(243, 'covid', 'covid', 'Injury', 1.0, true),
(244, 'infection', 'infection', 'Injury', 1.0, true),
(245, 'tooth', 'tooth', 'Injury', 0.6, true),
(246, 'sign', 'sign', 'Transaction', 0.3, true),
(247, 'blood', 'blood', 'Injury', 0.6, true),
(248, 'face', 'face', 'Injury', 0.3, true),
(250, 'contracts', 'contracts', 'Transaction', 0.6, true),
(252, 'waive', 'waive', 'Transaction', 1.0, true),
(253, 'five', 'five', 'Availability', 0.3, true),
(254, 'bench', 'bench', 'Availability', 0.3, true),
(257, 'downgraded', 'downgraded', 'Availability', 1.0, true),
(258, 'upgraded', 'upgraded', 'Availability', 1.0, true),
(259, 'start', 'start', 'Availability', 0.3, true)
ON CONFLICT ("Id") DO UPDATE SET
  "Keyword" = EXCLUDED."Keyword",
  "NormalizedKeyword" = EXCLUDED."NormalizedKeyword",
  "Category" = EXCLUDED."Category",
  "Weight" = EXCLUDED."Weight";
SQLEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Next, locally:

  dotnet ef migrations add AddKeywordProcessing \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API
  dotnet ef database update \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API

  psql -U postgres -d RotoMonsterTwitter -f keywords-seed.sql

Then run the API and process what's stored:

  curl -X POST "http://localhost:5080/api/processing/run?batchSize=500"
  curl "http://localhost:5080/api/processing/status"

NOTE: Ken's id 178 (day-to-day) normalizes to the same thing as
id 11 (day to day), so both will match the same text. Worth telling
him so he can retire one.
==================================================================
MSGEOF
