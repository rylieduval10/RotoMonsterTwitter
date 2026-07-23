namespace RotoMonsterTwitter.Model.Configuration;

public class TwitterApiOptions
{
    public const string SectionName = "TwitterApi";

    public string ApiKey { get; set; } = "";
    public string BaseUrl { get; set; } = "https://api.twitterapi.io";
    public string UserAgent { get; set; } = "RotoMonsterTwitter/1.0";
    public int MaxPagesPerFetch { get; set; } = 20;
}
