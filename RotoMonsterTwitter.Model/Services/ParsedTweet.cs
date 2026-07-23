using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.Model.Services;

public class ParsedTweet
{
    public Tweet Tweet { get; set; } = new();
    public TweetUser User { get; set; } = new();
    public List<TweetMedia> Media { get; set; } = new();
}

public class TweetPage
{
    public List<ParsedTweet> Tweets { get; set; } = new();
    public bool HasNextPage { get; set; }
    public string? NextCursor { get; set; }
}
