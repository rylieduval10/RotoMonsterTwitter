namespace RotoMonsterTwitter.Contracts.Results;

public class SetPlayerStatusResult : BaseResult
{
    public int Updated { get; set; }

    /// <summary>Player ids that matched no stored player.</summary>
    public List<int> NotFound { get; set; } = new();

    /// <summary>Status type ids that don't exist, so nothing was set for them.</summary>
    public List<int> InvalidStatusTypeIds { get; set; } = new();

    public List<TwitterPlayerResult> Players { get; set; } = new();
}
