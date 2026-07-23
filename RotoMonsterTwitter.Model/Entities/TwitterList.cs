namespace RotoMonsterTwitter.Model.Entities;

public class TwitterList
{
    public long ListId { get; set; }
    public int SportId { get; set; }
    public string Name { get; set; } = "";
    public bool IsActive { get; set; } = true;

    public long LastFetchedUnix { get; set; }
    public DateTime? LastFetchedAt { get; set; }
    public int LastTweetCount { get; set; }
}
