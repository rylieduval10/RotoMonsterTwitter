namespace RotoMonsterTwitter.Contracts.Results;

public class TweetResult
{
        public string AiText { get; set; }

    public string TweetId { get; set; } = "";
    public int SportId { get; set; }

    public DateTime CreatedDate { get; set; }
    public DateTime? DateAdded { get; set; }

    public string Text { get; set; } = "";

    public string TwitterUserId { get; set; } = "";
    public string ScreenUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string ImageUrl { get; set; } = "";
    public bool IsVerified { get; set; }
    public bool IsBlueVerified { get; set; }
    public bool IsNews { get; set; }
    public bool IsTop { get; set; }

    public bool? IsRetweet { get; set; }
    public DateTime? RetweetDate { get; set; }
    public string? RetweetUserScreenName { get; set; }
    public string? SourceTweetId { get; set; }
    public string? SourceTweetUserScreenName { get; set; }

    public int? RetweetCount { get; set; }
    public int? Followers { get; set; }

    public DateTime? ProcessedAt { get; set; }

    public List<TweetMediaResult> Media { get; set; } = new();

    /// <summary>Players referenced, best match first.</summary>
    public List<TweetPlayerMatch> Players { get; set; } = new();

    /// <summary>Teams referenced, best match first.</summary>
    public List<TweetTeamMatch> Teams { get; set; } = new();

    /// <summary>Link to the tweet on X. Derived from the user and tweet id.</summary>
    public string TweetUrl =>
        string.IsNullOrEmpty(ScreenUsername) || string.IsNullOrEmpty(TweetId)
            ? ""
            : $"https://twitter.com/{ScreenUsername}/status/{TweetId}";

    /// <summary>How long ago the tweet was posted, as of now.</summary>
    public TimeSpan TimeSinceCreated => DateTime.UtcNow - CreatedDate;


    /// <summary>Injury / availability / transaction keywords found.</summary>
    public List<TweetKeywordMatch> Keywords { get; set; } = new();
}

public class TweetMediaResult
{
    public string ImageUrl { get; set; } = "";
    public string MediaType { get; set; } = "photo";
    public string? VideoUrl { get; set; }
    public int? DurationMillis { get; set; }
    public short DisplayOrder { get; set; }
}

public class TweetPlayerMatch
{
    public int PlayerId { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public int? TeamId { get; set; }

    /// <summary>FullName, Alias or LastName.</summary>
    public string MatchType { get; set; } = "";

    /// <summary>1.0 solid, down to 0.35 for a common-word surname. Filter here.</summary>
    public decimal Confidence { get; set; }

    public int Occurrences { get; set; }
}

public class TweetTeamMatch
{
    public int TeamId { get; set; }
    public string City { get; set; } = "";
    public string Name { get; set; } = "";
    public string MatchType { get; set; } = "";
    public decimal Confidence { get; set; }
    public int Occurrences { get; set; }
}

public class TweetKeywordMatch
{
    public int KeywordId { get; set; }
    public string Keyword { get; set; } = "";
    public string Category { get; set; } = "";
    public decimal Weight { get; set; }
    public int Occurrences { get; set; }

}
