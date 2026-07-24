namespace RotoMonsterTwitter.Model.Entities;

public class TweetTeam
{
    public string TweetId { get; set; } = "";
    public int TeamId { get; set; }

    /// <summary>FullName, Name, Alias or Abbreviation.</summary>
    public string MatchType { get; set; } = "";

    public decimal Confidence { get; set; }
    public int Occurrences { get; set; } = 1;

    public Tweet? Tweet { get; set; }
    public TwitterTeam? Team { get; set; }
}
