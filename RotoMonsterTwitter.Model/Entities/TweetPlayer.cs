namespace RotoMonsterTwitter.Model.Entities;

public class TweetPlayer
{
    public string TweetId { get; set; } = "";
    public int PlayerId { get; set; }

    /// <summary>FullName, Alias or LastName.</summary>
    public string MatchType { get; set; } = "";

    /// <summary>
    /// 1.0 for a first+last hit, lower for a surname on its own, lowest when
    /// that surname is also an ordinary English word. Filter on this.
    /// </summary>
    public decimal Confidence { get; set; }

    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterPlayer? Player { get; set; }
}
