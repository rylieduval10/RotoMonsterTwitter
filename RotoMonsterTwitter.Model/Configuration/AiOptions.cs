namespace RotoMonsterTwitter.Model.Configuration;

/// <summary>
/// AI summarisation settings. Defaults to Google Gemini. The model string and
/// key are config so they can change without a rebuild - Gemini model names in
/// particular move around.
/// </summary>
public class AiOptions
{
    public const string SectionName = "Ai";

    /// <summary>Only "gemini" is implemented today. Here so a second provider is a config flip.</summary>
    public string Provider { get; set; } = "gemini";

    public string ApiKey { get; set; } = "";

    /// <summary>e.g. gemini-2.0-flash. Set the exact model Ken wants here.</summary>
    public string Model { get; set; } = "gemini-2.0-flash";

    /// <summary>Base endpoint; the model and :generateContent are appended.</summary>
    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com/v1beta/models";

    /// <summary>
    /// The instruction wrapped around the tweet. {tweet} is replaced with the
    /// tweet text. Editable so Ken can tune the tone without a deploy.
    /// </summary>
    public string PromptTemplate { get; set; } =
        "Summarize the following tweet as a brief player news note using common "
        + "medical and fantasy-sports terms. Be factual, one or two sentences, no "
        + "hashtags or links. If there is no player news, say so plainly.\n\nTweet:\n{tweet}";

    public bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey);
}
