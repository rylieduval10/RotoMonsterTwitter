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
    public DbSet<TwitterKeyword> TwitterKeywords => Set<TwitterKeyword>();
    public DbSet<TweetKeyword> TweetKeywords => Set<TweetKeyword>();
    public DbSet<TwitterPlayer> TwitterPlayers => Set<TwitterPlayer>();
    public DbSet<TwitterPlayerAlias> TwitterPlayerAliases => Set<TwitterPlayerAlias>();
    public DbSet<TwitterTeam> TwitterTeams => Set<TwitterTeam>();
    public DbSet<TwitterTeamAlias> TwitterTeamAliases => Set<TwitterTeamAlias>();
    public DbSet<TweetPlayer> TweetPlayers => Set<TweetPlayer>();
    public DbSet<TweetTeam> TweetTeams => Set<TweetTeam>();

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
            e.HasIndex(x => x.DateAdded);
            e.HasIndex(x => x.ProcessedAt);
            e.HasIndex(x => new { x.SportId, x.DateAdded });
            e.HasIndex(x => x.TwitterUserId);

            e.HasOne(x => x.TweetUser)
             .WithMany()
             .HasForeignKey(x => x.TwitterUserId)
             .HasPrincipalKey(x => x.TwitterUserId)
             .OnDelete(DeleteBehavior.Restrict);

            e.HasMany(x => x.Keywords)
             .WithOne(x => x.Tweet!)
             .HasForeignKey(x => x.TweetId)
             .OnDelete(DeleteBehavior.Cascade);

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
            e.HasIndex(x => x.IsNews);
            e.HasIndex(x => x.IsTop);
        });

        b.Entity<TwitterKeyword>(e =>
        {
            e.ToTable("TwitterKeywords");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Keyword).HasMaxLength(100).IsRequired();
            e.Property(x => x.NormalizedKeyword).HasMaxLength(100).IsRequired();
            e.Property(x => x.Category).HasMaxLength(40).IsRequired();
            e.Property(x => x.Weight).HasPrecision(3, 2);

            e.HasIndex(x => x.NormalizedKeyword);
            e.HasIndex(x => x.Category);
        });

        b.Entity<TweetKeyword>(e =>
        {
            e.ToTable("TweetKeywords");
            e.HasKey(x => new { x.TweetId, x.KeywordId });
            e.Property(x => x.TweetId).HasMaxLength(50).IsRequired();

            e.HasIndex(x => x.KeywordId);

            e.HasOne(x => x.Keyword)
             .WithMany()
             .HasForeignKey(x => x.KeywordId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<TwitterPlayer>(e =>
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
