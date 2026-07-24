namespace RotoMonsterTwitter.Contracts.Results;

public class ProcessTweetsResult : BaseResult
{
    public int TweetsProcessed { get; set; }
    public int TweetsWithMatches { get; set; }

    public int KeywordMatches { get; set; }
    public int PlayerMatches { get; set; }
    public int TeamMatches { get; set; }

    public int RemainingUnprocessed { get; set; }
    public int ActiveKeywords { get; set; }
    public int ActivePlayers { get; set; }
}
