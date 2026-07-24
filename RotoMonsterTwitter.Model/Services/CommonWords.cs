namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Surnames that are also ordinary English words. A tweet saying "some love
/// for Walsh" should not read as a reference to Kevin Love, so a surname-only
/// hit on one of these is recorded at low confidence.
///
/// This is a backstop. Ken can set FullNameOnly per player, which is stronger.
/// </summary>
public static class CommonWords
{
    private static readonly HashSet<string> Words = new(StringComparer.Ordinal)
    {
        "love", "green", "brown", "white", "black", "young", "rose", "wood",
        "smart", "king", "bird", "hart", "fox", "wells", "reed", "bell",
        "little", "sharp", "banks", "rich", "moody", "champagne", "star",
        "day", "may", "june", "march", "will", "mark", "grant", "chase",
        "cash", "coach", "field", "gay", "hall", "hill", "house", "hunt",
        "lamb", "land", "lane", "long", "lord", "man", "mills", "moon",
        "morning", "pace", "page", "park", "price", "rice", "ring", "river",
        "rivers", "sands", "shine", "short", "snow", "stone", "storm",
        "strong", "summer", "swift", "walker", "ward", "waters", "west",
        "wise", "winter", "best", "bright", "case", "close", "cross",
        "dean", "dice", "drew", "east", "fine", "flowers", "free", "frost",
        "gates", "gold", "good", "hope", "just", "key", "knight", "law",
        "light", "mason", "north", "pope", "power", "quick", "rain", "read",
        "real", "roll", "sage", "sale", "salt", "score", "seal", "second",
        "sky", "small", "south", "spring", "steel", "stern", "still",
        "stout", "street", "sun", "true", "wall", "watch", "well", "wild",
        "win", "wolf", "worth"
    };

    public static bool IsCommonWord(string normalizedWord)
        => Words.Contains(normalizedWord);
}
