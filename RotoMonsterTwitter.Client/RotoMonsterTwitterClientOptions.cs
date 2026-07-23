namespace RotoMonsterTwitter.Client;

public class RotoMonsterTwitterClientOptions
{
    public const string SectionName = "RotoMonsterTwitter";

    /// <summary>Root url of the API, e.g. https://twitter.rotomonster.com</summary>
    public string BaseUrl { get; set; } = "";

    /// <summary>Sent as X-API-Key on every request.</summary>
    public string ApiKey { get; set; } = "";

    public int TimeoutSeconds { get; set; } = 30;
}
