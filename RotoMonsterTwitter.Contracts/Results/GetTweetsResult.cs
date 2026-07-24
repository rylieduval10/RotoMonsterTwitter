namespace RotoMonsterTwitter.Contracts.Results;

public class GetTweetsResult : BaseResult
{
    public List<TweetResult> Tweets { get; set; } = new();
    public int TotalCount { get; set; }
}
