namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Given names that also occur as surnames. A last-name-only hit on one of
/// these, with the player's own first name absent, is far more likely to be
/// someone else's first name in the tweet ("Ryan Silverfield" is not a player
/// named Ryan) than a real reference, so we drop it.
///
/// This only affects surname-only matching. Full name and alias matches are
/// untouched, so a player actually named Ryan still matches on "First Ryan".
/// </summary>
public static class CommonFirstNames
{
    private static readonly HashSet<string> Names = new(StringComparer.Ordinal)
    {
        "ryan", "cole", "cameron", "brandon", "tyler", "jordan", "austin",
        "mason", "dawson", "grant", "chase", "carson", "dillon", "gordon",
        "marshall", "spencer", "riley", "reid", "dean", "drew", "blake",
        "brooks", "carter", "cooper", "duncan", "hayes", "hudson", "hunter",
        "jack", "jackson", "keegan", "kennedy", "lincoln", "maddox", "parker",
        "pierce", "quinn", "reed", "sawyer", "scott", "wesley", "grayson",
        "harrison", "jefferson", "lawson", "nelson", "payton", "preston"
    };

    public static bool IsCommonFirstName(string normalizedWord)
        => Names.Contains(normalizedWord);
}
