namespace RotoMonsterTwitter.Model.Configuration;

public class ApiKeyOptions
{
    public const string SectionName = "ApiKeys";

    public string HeaderName { get; set; } = "X-API-Key";

    /// <summary>
    /// Client name -> key. Named so logs show who called, and so one client's
    /// key can be revoked without disturbing the others.
    /// </summary>
    public Dictionary<string, string> Clients { get; set; } = new();

    /// <summary>Paths that skip the check. Health stays open for monitoring.</summary>
    public List<string> AnonymousPaths { get; set; } = new() { "/health" };
}
