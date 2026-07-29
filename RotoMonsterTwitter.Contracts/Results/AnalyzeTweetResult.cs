namespace RotoMonsterTwitter.Contracts.Results;

public class AnalyzeTweetResult : BaseResult
{
    public string? TweetId { get; set; }

    /// <summary>The generated summary, ready to drop into the news text box.</summary>
    public string Summary { get; set; } = "";

    /// <summary>Which model produced it, for the record.</summary>
    public string? Model { get; set; }
}
