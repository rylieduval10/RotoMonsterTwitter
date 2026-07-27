namespace RotoMonsterTwitter.Contracts.Results;

public class GetPlayerStatusTypesResult : BaseResult
{
    public List<PlayerStatusTypeResult> StatusTypes { get; set; } = new();
}

public class PlayerStatusTypeResult
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public bool IsActive { get; set; }
}
