namespace RotoMonsterTwitter.Model.Entities;

public class TweetMedia
{
    public string TweetId { get; set; } = "";
    public short DisplayOrder { get; set; }

    /// <summary>Photo url, or the poster thumbnail for a video.</summary>
    public string ImageUrl { get; set; } = "";

    /// <summary>photo, video, or animated_gif.</summary>
    public string MediaType { get; set; } = "photo";

    /// <summary>Highest-bitrate mp4 for video/gif media; null for photos.</summary>
    public string? VideoUrl { get; set; }

    public int? DurationMillis { get; set; }

    public Tweet? Tweet { get; set; }
}
