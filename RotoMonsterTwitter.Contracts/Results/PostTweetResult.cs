namespace RotoMonsterTwitter.Contracts.Results;

public class PostTweetResult : BaseResult
{
    public string? TweetId { get; set; }
    public string? Text { get; set; }
}
