using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Turns tweet text into a form that can be matched against reliably.
///
/// Tweets are messy in ways that quietly break naive matching: curly
/// apostrophes rather than straight ones, accented names, @mentions and
/// hashtags that contain ordinary words, and t.co links on the end of
/// everything. This flattens all of that.
///
/// Output is space-padded, so a caller can test " keyword " and get whole-word
/// matching for single words and phrases alike without any regex.
/// </summary>
public static class TextNormalizer
{
    private static readonly Regex UrlPattern =
        new(@"https?://\S+", RegexOptions.Compiled);

    private static readonly Regex MentionPattern =
        new(@"(?<![\w])@\w+", RegexOptions.Compiled);

    private static readonly Regex NonAlphanumeric =
        new(@"[^a-z0-9]+", RegexOptions.Compiled);

    private static readonly Regex Whitespace =
        new(@"\s+", RegexOptions.Compiled);

    /// <summary>Normalize tweet text. Returns a space-padded token string.</summary>
    public static string NormalizeText(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return " ";

        var value = text;

        // Links and mentions carry words that aren't really in the tweet -
        // "@King_Cutty1" should not count as a reference to a player named King.
        value = UrlPattern.Replace(value, " ");
        value = MentionPattern.Replace(value, " ");

        // Hashtags keep their word: #Saints should still read as saints.
        value = value.Replace("#", " ");

        return " " + Flatten(value) + " ";
    }

    /// <summary>Normalize a keyword or name. Not padded.</summary>
    public static string NormalizeTerm(string? term)
        => string.IsNullOrWhiteSpace(term) ? "" : Flatten(term);

    private static string Flatten(string value)
    {
        value = value.ToLowerInvariant();

        // Apostrophes vanish rather than becoming spaces, so "won't" reads as
        // "wont" - which is how Ken has it in his keyword list.
        value = value.Replace("'", "").Replace("\u2019", "").Replace("\u02BC", "");

        value = StripDiacritics(value);
        value = NonAlphanumeric.Replace(value, " ");
        value = Whitespace.Replace(value, " ");

        return value.Trim();
    }

    /// <summary>Jokic and Jokić should be the same word.</summary>
    private static string StripDiacritics(string value)
    {
        var decomposed = value.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(c);
            }
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    /// <summary>Count non-overlapping occurrences of a normalized term.</summary>
    public static int CountOccurrences(string paddedText, string normalizedTerm)
    {
        if (string.IsNullOrEmpty(normalizedTerm)) return 0;

        var needle = " " + normalizedTerm + " ";
        var count = 0;
        var index = 0;

        while (true)
        {
            index = paddedText.IndexOf(needle, index, StringComparison.Ordinal);
            if (index < 0) break;

            count++;

            // Step back one so " a b " can match twice in " a b a b ".
            index += needle.Length - 1;
        }

        return count;
    }
}
