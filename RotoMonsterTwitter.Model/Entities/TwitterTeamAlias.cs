namespace RotoMonsterTwitter.Model.Entities;

public class TwitterTeamAlias
{
    public int Id { get; set; }
    public int TeamId { get; set; }

    public string Alias { get; set; } = "";
    public string NormalizedAlias { get; set; } = "";

    public TwitterTeam? Team { get; set; }
}
