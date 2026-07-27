namespace RotoMonsterTwitter.Contracts.Results;

public class GetPlayersResult : BaseResult
{
    public int TotalCount { get; set; }
    public List<TwitterPlayerResult> Players { get; set; } = new();
}

public class TwitterPlayerResult
{
    public int PlayerId { get; set; }
    public int SportId { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public int? TeamId { get; set; }
    public bool FullNameOnly { get; set; }
    public bool IsActive { get; set; }

    public int? PlayerStatusTypeId { get; set; }

    /// <summary>Resolved from PlayerStatusTypes, so callers don't have to join.</summary>
    public string? PlayerStatusTitle { get; set; }

    public List<string> Aliases { get; set; } = new();
}
