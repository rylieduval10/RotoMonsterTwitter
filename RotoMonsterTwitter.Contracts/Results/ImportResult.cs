namespace RotoMonsterTwitter.Contracts.Results;

public class ImportResult : BaseResult
{
    public int SportId { get; set; }
    public int PlayersImported { get; set; }
    public int TeamsImported { get; set; }
    public int PlayerAliases { get; set; }
    public int TeamAliases { get; set; }

    /// <summary>Rows dropped because they were missing a name or an id.</summary>
    public int Skipped { get; set; }
}
