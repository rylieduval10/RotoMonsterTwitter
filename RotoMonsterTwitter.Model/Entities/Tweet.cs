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

    /// <summary>Set from the tweet's user during processing. Filterable.</summary>
    public bool IsNews { get; set; }

    /// <summary>
    /// Set during processing: the user is IsTop, or the tweet has at least one
    /// player and at least one keyword. A per-tweet signal, not a per-user one.
    /// </summary>
    public bool IsTop { get; set; }

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
