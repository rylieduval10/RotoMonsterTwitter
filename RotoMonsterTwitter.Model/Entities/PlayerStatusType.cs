namespace RotoMonsterTwitter.Model.Entities;

/// <summary>
/// Ken's status vocabulary - Injured, Questionable, Traded and so on. The ids
/// are his and have gaps, so they're never generated here.
/// </summary>
public class PlayerStatusType
{
    public int Id { get; set; }

    public string Title { get; set; } = "";

    /// <summary>
    /// The seeded list is wider than they need. Turn a row off rather than
    /// deleting it, since players may already point at it.
    /// </summary>
    public bool IsActive { get; set; } = true;
}
