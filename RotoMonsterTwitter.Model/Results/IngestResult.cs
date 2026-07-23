namespace RotoMonsterTwitter.Model.Results;

public class IngestResult : BaseResult
{
    public long ListId { get; set; }
    public int SportId { get; set; }
    public int PagesFetched { get; set; }
    public int TweetsReturned { get; set; }
    public int NewTweets { get; set; }
    public int NewUsers { get; set; }
    public long PreviousSinceUnix { get; set; }
    public long NewSinceUnix { get; set; }
}
