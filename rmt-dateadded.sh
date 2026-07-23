#!/usr/bin/env bash
#
# RotoMonsterTwitter - filter on DateAdded (when we stored a tweet) as well as
# CreatedDate (when it was posted), so a polling client can ask for everything
# new since its last check and not miss late-arriving older tweets.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Updating request..."

cat > RotoMonsterTwitter.Model/Requests/GetTweetsRequest.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Requests;

public class GetTweetsRequest
{
    public int? SportId { get; set; }
    public string? ScreenUsername { get; set; }

    /// <summary>Filters on when the tweet was posted.</summary>
    public DateTime? CreatedOnOrAfter { get; set; }
    public DateTime? CreatedOnOrBefore { get; set; }

    /// <summary>
    /// Filters on when we stored the tweet. This is the one a polling client
    /// wants: pass the DateAdded of the newest tweet you've already handled,
    /// and you'll get everything since, including older tweets that only
    /// arrived in a later backfill.
    /// </summary>
    public DateTime? AddedOnOrAfter { get; set; }
    public DateTime? AddedOnOrBefore { get; set; }

    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 100;

    /// <summary>
    /// Order by DateAdded rather than CreatedDate. Pair this with
    /// AddedOnOrAfter when polling so paging stays stable.
    /// </summary>
    public bool OrderByDateAdded { get; set; } = false;
}
CSEOF

echo "Updating result..."

cat > RotoMonsterTwitter.Model/Results/TweetResult.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Results;

public class TweetResult
{
    public string TweetId { get; set; } = "";
    public int SportId { get; set; }

    /// <summary>When the tweet was posted.</summary>
    public DateTime CreatedDate { get; set; }

    /// <summary>When we stored it. Record this as your polling watermark.</summary>
    public DateTime? DateAdded { get; set; }

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

echo "Updating tweet service..."

python3 - <<'PYEOF'
import pathlib

p = pathlib.Path("RotoMonsterTwitter.Model/Services/TweetService.cs")
text = p.read_text()

# --- extra filters ---
old_filter = """        if (!string.IsNullOrWhiteSpace(request.SearchText))
            query = query.Where(t => EF.Functions.ILike(t.Text, $"%{request.SearchText}%"));"""

new_filter = """        if (request.AddedOnOrAfter.HasValue)
            query = query.Where(t => t.DateAdded >= request.AddedOnOrAfter.Value);

        if (request.AddedOnOrBefore.HasValue)
            query = query.Where(t => t.DateAdded <= request.AddedOnOrBefore.Value);

        if (!string.IsNullOrWhiteSpace(request.SearchText))
            query = query.Where(t => EF.Functions.ILike(t.Text, $"%{request.SearchText}%"));"""

if "AddedOnOrAfter" not in text:
    if old_filter not in text:
        raise SystemExit("ERROR: could not find the SearchText filter block")
    text = text.replace(old_filter, new_filter)

# --- ordering ---
old_order = """        var tweets = await query
            .OrderByDescending(t => t.CreatedDate)"""

new_order = """        query = request.OrderByDateAdded
            ? query.OrderByDescending(t => t.DateAdded).ThenByDescending(t => t.CreatedDate)
            : query.OrderByDescending(t => t.CreatedDate);

        var tweets = await query"""

if "OrderByDateAdded" not in text:
    if old_order not in text:
        raise SystemExit("ERROR: could not find the ordering block")
    text = text.replace(old_order, new_order)

# --- expose DateAdded ---
if "DateAdded = t.DateAdded" not in text:
    text = text.replace(
        "        CreatedDate = t.CreatedDate,\n        Text = t.Text,",
        "        CreatedDate = t.CreatedDate,\n        DateAdded = t.DateAdded,\n        Text = t.Text,")

p.write_text(text)
print("  patched TweetService.cs")

# --- index on DateAdded ---
p = pathlib.Path("RotoMonsterTwitter.Model/Data/TwitterDbContext.cs")
text = p.read_text()

if "x.DateAdded" not in text:
    text = text.replace(
        "            e.HasIndex(x => new { x.SportId, x.CreatedDate });",
        "            e.HasIndex(x => new { x.SportId, x.CreatedDate });\n"
        "            e.HasIndex(x => x.DateAdded);\n"
        "            e.HasIndex(x => new { x.SportId, x.DateAdded });")
    p.write_text(text)
    print("  patched TwitterDbContext.cs")

# --- client convenience method ---
p = pathlib.Path("RotoMonsterTwitter.Client/IRotoMonsterTwitterClient.cs")
text = p.read_text()

if "GetTweetsAddedSinceAsync" not in text:
    text = text.replace(
        "    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);",
        "    /// <summary>\n"
        "    /// Everything stored since the given point, newest first. Pass the\n"
        "    /// DateAdded of the newest tweet you already handled.\n"
        "    /// </summary>\n"
        "    Task<GetTweetsResult> GetTweetsAddedSinceAsync(DateTime addedOnOrAfter,\n"
        "        int? sportId = null, int maxResults = 100, CancellationToken ct = default);\n"
        "\n"
        "    Task<ReadTweetResult> ReadTweetAsync(string tweetId, CancellationToken ct = default);")
    p.write_text(text)
    print("  patched IRotoMonsterTwitterClient.cs")

p = pathlib.Path("RotoMonsterTwitter.Client/RotoMonsterTwitterClient.cs")
text = p.read_text()

if "GetTweetsAddedSinceAsync" not in text:
    text = text.replace(
        "    public async Task<ReadTweetResult> ReadTweetAsync(",
        "    public Task<GetTweetsResult> GetTweetsAddedSinceAsync(\n"
        "        DateTime addedOnOrAfter, int? sportId = null, int maxResults = 100,\n"
        "        CancellationToken ct = default)\n"
        "        => GetTweetsAsync(new GetTweetsRequest\n"
        "        {\n"
        "            AddedOnOrAfter = addedOnOrAfter,\n"
        "            SportId = sportId,\n"
        "            MaxResults = maxResults,\n"
        "            OrderByDateAdded = true\n"
        "        }, ct);\n"
        "\n"
        "    public async Task<ReadTweetResult> ReadTweetAsync(")
    p.write_text(text)
    print("  patched RotoMonsterTwitterClient.cs")
PYEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Now generate the migration and a fresh prod schema script:

  dotnet ef migrations add AddDateAddedIndexes \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API
  dotnet ef database update \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API

  dotnet ef migrations script --idempotent -o rmt-schema.sql \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API

The polling pattern for MonitorNBA:

  var result = await client.GetTweetsAddedSinceAsync(lastSeen, sportId: 1);
  // handle result.Tweets
  // store the max DateAdded as the new lastSeen
==================================================================
MSGEOF
