namespace RotoMonsterTwitter.Model.Results;

public class TweetResult
{
    public string TweetId { get; set; } = "";
    public int SportId { get; set; }
    public DateTime CreatedDate { get; set; }
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
