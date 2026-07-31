namespace RotoMonsterTwitter.Contracts.Results;

public class SetAiTextResult : BaseResult
{
    public string TweetId { get; set; } = "";

    /// <summary>False means no tweet with that id - distinct from a successful write.</summary>
    public bool Found { get; set; }

    /// <summary>What is stored after the write. Null when cleared.</summary>
    public string? AiText { get; set; }
}
