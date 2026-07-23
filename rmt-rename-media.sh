#!/usr/bin/env bash
#
# RotoMonsterTwitter - rename TweetImages -> TweetMedia now that the table
# holds videos and gifs as well as photos.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Replacing TweetImage entity with TweetMedia..."

rm -f RotoMonsterTwitter.Model/Entities/TweetImage.cs

cat > RotoMonsterTwitter.Model/Entities/TweetMedia.cs <<'CSEOF'
namespace RotoMonsterTwitter.Model.Entities;

public class TweetMedia
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
}
CSEOF

echo "Updating DbContext..."

cat > RotoMonsterTwitter.Model/Data/TwitterDbContext.cs <<'CSEOF'
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Data;

public class TwitterDbContext : DbContext
{
    public TwitterDbContext(DbContextOptions<TwitterDbContext> options)
        : base(options) { }

    public DbSet<Tweet> Tweets => Set<Tweet>();
    public DbSet<TweetMedia> TweetMedia => Set<TweetMedia>();
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

            e.HasMany(x => x.Media)
             .WithOne(x => x.Tweet!)
             .HasForeignKey(x => x.TweetId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TweetMedia>(e =>
        {
            e.ToTable("TweetMedia");
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

echo "Updating services..."

cat > RotoMonsterTwitter.Model/Services/ParsedTweet.cs <<'CSEOF'
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Services;

public class ParsedTweet
{
    public Tweet Tweet { get; set; } = new();
    public TweetUser User { get; set; } = new();
    public List<TweetMedia> Media { get; set; } = new();
}

public class TweetPage
{
    public List<ParsedTweet> Tweets { get; set; } = new();
    public bool HasNextPage { get; set; }
    public string? NextCursor { get; set; }
}
CSEOF

# Targeted edits rather than rewriting the two large service files.
python3 - <<'PYEOF'
import pathlib

edits = {
    "RotoMonsterTwitter.Model/Services/TwitterApiService.cs": [
        ("var media = new List<TweetImage>();", "var media = new List<TweetMedia>();"),
        ("media.Add(new TweetImage", "media.Add(new TweetMedia"),
    ],
    "RotoMonsterTwitter.Model/Services/TweetIngestService.cs": [
        ("parsed.Tweet.Images = parsed.Media;", "parsed.Tweet.Media = parsed.Media;"),
    ],
    "RotoMonsterTwitter.Model/Services/TweetService.cs": [
        (".Include(t => t.Images)", ".Include(t => t.Media)"),
        ("Media = t.Images", "Media = t.Media"),
    ],
}

for path, pairs in edits.items():
    p = pathlib.Path(path)
    text = p.read_text()
    for old, new in pairs:
        if old not in text and new not in text:
            raise SystemExit(f"ERROR: could not find in {path}:\n  {old}")
        text = text.replace(old, new)
    p.write_text(text)
    print(f"  patched {path}")
PYEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Now migrate:

  dotnet ef migrations add RenameTweetImagesToTweetMedia \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API
  dotnet ef database update \
      -p RotoMonsterTwitter.Model -s RotoMonsterTwitter.API

NOTE: EF will most likely generate a DROP of TweetImages and a
CREATE of TweetMedia rather than an ALTER ... RENAME. That loses
the sample media rows, which is fine locally - just re-run the
IngestJson call afterwards to repopulate.

Open the generated migration first if you want to confirm.
==================================================================
MSGEOF
