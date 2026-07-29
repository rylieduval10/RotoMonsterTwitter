namespace RotoMonsterTwitter.Contracts.Requests;

public class AnalyzeTweetRequest
{
    /// <summary>The tweet text to summarize. Required.</summary>
    public string Text { get; set; } = "";

    /// <summary>Optional - echoed back so the caller can correlate.</summary>
    public string? TweetId { get; set; }
}
