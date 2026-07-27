namespace RotoMonsterTwitter.Contracts.Requests;

public class SetPlayerStatusRequest
{
    public List<PlayerStatusUpdate> Players { get; set; } = new();
}

public class PlayerStatusUpdate
{
    public int PlayerId { get; set; }

    /// <summary>
    /// The status type id, or null to clear it. Note this differs from the
    /// import, where null means "leave it alone" - here setting status is the
    /// whole point, so null is an explicit clear.
    /// </summary>
    public int? PlayerStatusTypeId { get; set; }
}
