namespace RotoMonsterTwitter.Model.Entities;

public class TwitterTeam
{
    public int TeamId { get; set; }
    public int SportId { get; set; }

    public string City { get; set; } = "";
    public string Name { get; set; } = "";
    public string Abbreviation { get; set; } = "";

    public string NormalizedFullName { get; set; } = "";
    public string NormalizedName { get; set; } = "";
    public string NormalizedAbbreviation { get; set; } = "";

    public bool IsActive { get; set; } = true;

    public List<TwitterTeamAlias> Aliases { get; set; } = new();
}
