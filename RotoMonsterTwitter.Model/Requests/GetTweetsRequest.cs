namespace RotoMonsterTwitter.Model.Requests;

public class GetTweetsRequest
{
    public int? SportId { get; set; }
    public string? ScreenUsername { get; set; }
    public DateTime? CreatedOnOrAfter { get; set; }
    public DateTime? CreatedOnOrBefore { get; set; }
    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 100;
}
