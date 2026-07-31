namespace RotoMonsterTwitter.Contracts.Requests;

public class SetAiTextRequest
{
    public string TweetId { get; set; } = "";

    /// <summary>Blank or whitespace clears the stored summary.</summary>
    public string? AiText { get; set; }
}
