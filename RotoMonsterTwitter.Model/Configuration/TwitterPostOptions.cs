namespace RotoMonsterTwitter.Model.Configuration;

/// <summary>
/// OAuth 1.0a credentials for posting to X. These come from an X developer
/// app - twitterapi.io is read-only and cannot post.
/// </summary>
public class TwitterPostOptions
{
    public const string SectionName = "TwitterPost";

    public string ConsumerKey { get; set; } = "";
    public string ConsumerSecret { get; set; } = "";
    public string AccessToken { get; set; } = "";
    public string AccessTokenSecret { get; set; } = "";

    public string PostUrl { get; set; } = "https://api.twitter.com/2/tweets";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ConsumerKey) &&
        !string.IsNullOrWhiteSpace(ConsumerSecret) &&
        !string.IsNullOrWhiteSpace(AccessToken) &&
        !string.IsNullOrWhiteSpace(AccessTokenSecret);
}
