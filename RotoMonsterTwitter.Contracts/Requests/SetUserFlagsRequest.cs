namespace RotoMonsterTwitter.Contracts.Requests;

public class SetUserFlagsRequest
{
    public List<UserFlagUpdate> Users { get; set; } = new();
}

public class UserFlagUpdate
{
    /// <summary>Match on this or on TwitterUserId. A leading @ is fine.</summary>
    public string? ScreenUsername { get; set; }
    public string? TwitterUserId { get; set; }

    /// <summary>Null leaves the existing value alone.</summary>
    public bool? IsNews { get; set; }
    public bool? IsTop { get; set; }
}
