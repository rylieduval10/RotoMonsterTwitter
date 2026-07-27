namespace RotoMonsterTwitter.Contracts.Results;

public class SetUserFlagsResult : BaseResult
{
    public int Updated { get; set; }

    /// <summary>Identifiers that matched no stored user - usually a typo'd handle.</summary>
    public List<string> NotFound { get; set; } = new();

    public List<TweetUserResult> Users { get; set; } = new();
}
