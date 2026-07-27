namespace RotoMonsterTwitter.Contracts.Requests;

public class GetUsersRequest
{
    public bool? IsNews { get; set; }
    public bool? IsTop { get; set; }

    /// <summary>Partial match on screen username or display name.</summary>
    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 200;
}
