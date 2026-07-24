namespace RotoMonsterTwitter.Model.Entities;

public class TwitterKeyword
{
    /// <summary>Ken's own ids, preserved so his existing references still line up.</summary>
    public int Id { get; set; }

    /// <summary>As Ken wrote it. Shown in the UI.</summary>
    public string Keyword { get; set; } = "";

    /// <summary>Lowercased, de-accented, punctuation stripped. What matching uses.</summary>
    public string NormalizedKeyword { get; set; } = "";

    /// <summary>Injury, Availability, Transaction, Discipline, Personal, TeamActivity.</summary>
    public string Category { get; set; } = "Injury";

    /// <summary>
    /// How much to trust a hit. Ordinary English words that happen to be on the
    /// list (start, bench, five, face) sit at 0.3 so they can be filtered out.
    /// </summary>
    public decimal Weight { get; set; } = 1.0m;

    public bool IsActive { get; set; } = true;
}
