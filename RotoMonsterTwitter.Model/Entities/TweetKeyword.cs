namespace RotoMonsterTwitter.Model.Entities;

public class TweetKeyword
{
    public string TweetId { get; set; } = "";
    public int KeywordId { get; set; }

    /// <summary>How many times it appeared in the tweet.</summary>
    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterKeyword? Keyword { get; set; }
}
