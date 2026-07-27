namespace RotoMonsterTwitter.Contracts.Requests;

public class GetPlayersRequest
{
    public int? SportId { get; set; }

    /// <summary>Only players carrying this exact status.</summary>
    public int? PlayerStatusTypeId { get; set; }

    /// <summary>True for players with any status set, false for those without.</summary>
    public bool? HasStatus { get; set; }

    /// <summary>Partial match on first or last name.</summary>
    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 200;
}
