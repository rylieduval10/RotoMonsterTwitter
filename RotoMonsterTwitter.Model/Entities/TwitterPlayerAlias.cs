namespace RotoMonsterTwitter.Model.Entities;

public class TwitterPlayerAlias
{
    public int Id { get; set; }
    public int PlayerId { get; set; }

    public string Alias { get; set; } = "";
    public string NormalizedAlias { get; set; } = "";

    public TwitterPlayer? Player { get; set; }
}
