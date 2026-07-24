namespace RotoMonsterTwitter.Contracts.Requests;

public class DeleteTweetsRequest
{
    public List<string>? TweetIds { get; set; }
    public DateTime? CreatedBefore { get; set; }
    public int? SportId { get; set; }
}
