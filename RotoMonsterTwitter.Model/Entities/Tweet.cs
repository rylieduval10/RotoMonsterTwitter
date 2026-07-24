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
