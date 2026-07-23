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
