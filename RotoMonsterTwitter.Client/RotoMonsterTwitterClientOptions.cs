namespace RotoMonsterTwitter.Client;

public class RotoMonsterTwitterClientOptions
{
    public const string SectionName = "RotoMonsterTwitter";

    /// <summary>Root url of the API, e.g. https://twitter.rotomonster.com</summary>
    public string BaseUrl { get; set; } = "";

    public int TimeoutSeconds { get; set; } = 30;
}
