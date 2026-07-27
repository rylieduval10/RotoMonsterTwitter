namespace RotoMonsterTwitter.Model.Entities;

public class TwitterPlayer
{
    /// <summary>Basketball Monster's player id. Ken's, not ours.</summary>
    public int PlayerId { get; set; }

    public int SportId { get; set; }

    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";

    public string NormalizedFullName { get; set; } = "";
    public string NormalizedLastName { get; set; } = "";

    public int? TeamId { get; set; }

    /// <summary>
    /// Ken's existing practice: for surnames that are ordinary words (Love,
    /// Green, White) only match when the first name is present too.
    /// </summary>
    public bool FullNameOnly { get; set; }

    public bool IsActive { get; set; } = true;

    /// <summary>
    /// One status at a time, from PlayerStatusTypes. Null means none set.
    /// </summary>
    public int? PlayerStatusTypeId { get; set; }

    public List<TwitterPlayerAlias> Aliases { get; set; } = new();
}
