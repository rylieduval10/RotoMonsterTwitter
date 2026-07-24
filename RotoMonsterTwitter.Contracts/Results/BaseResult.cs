namespace RotoMonsterTwitter.Contracts.Results;

public class BaseResult
{
    public bool Success { get; set; } = true;
    public string? ErrorMessage { get; set; }
}
