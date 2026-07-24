namespace RotoMonsterTwitter.Model.Requests;

/// <summary>
/// The whole player and team pool for one sport. Sent complete each time -
/// the API replaces what it has rather than diffing, so the sender never has
/// to track what changed.
/// </summary>
public class PlayerImportRequest
{
    /// <summary>1 = basketball, 2 = baseball.</summary>
    public int SportId { get; set; }

    public List<PlayerImport> Players { get; set; } = new();
    public List<TeamImport> Teams { get; set; } = new();
}

public class PlayerImport
{
    public int PlayerId { get; set; }
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public int? TeamId { get; set; }

    /// <summary>
    /// Set for surnames that are ordinary words - Love, Green, White, Young.
    /// Those will only match when the first name appears too.
    /// </summary>
    public bool FullNameOnly { get; set; }

    public List<string> Aliases { get; set; } = new();
}

public class TeamImport
{
    public int TeamId { get; set; }
    public string City { get; set; } = "";
    public string Name { get; set; } = "";
    public string Abbreviation { get; set; } = "";

    /// <summary>Blazers, Sixers, Cavs - however people actually write it.</summary>
    public List<string> Aliases { get; set; } = new();
}
