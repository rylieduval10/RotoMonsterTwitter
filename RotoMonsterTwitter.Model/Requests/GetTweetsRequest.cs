namespace RotoMonsterTwitter.Model.Requests;

public class GetTweetsRequest
{
    public int? SportId { get; set; }
    public string? ScreenUsername { get; set; }

    /// <summary>Filters on when the tweet was posted.</summary>
    public DateTime? CreatedOnOrAfter { get; set; }
    public DateTime? CreatedOnOrBefore { get; set; }

    /// <summary>
    /// Filters on when we stored the tweet. This is the one a polling client
    /// wants: pass the DateAdded of the newest tweet you've already handled,
    /// and you'll get everything since, including older tweets that only
    /// arrived in a later backfill.
    /// </summary>
    public DateTime? AddedOnOrAfter { get; set; }
    public DateTime? AddedOnOrBefore { get; set; }

    public string? SearchText { get; set; }

    public int Skip { get; set; } = 0;
    public int MaxResults { get; set; } = 100;

    /// <summary>
    /// Order by DateAdded rather than CreatedDate. Pair this with
    /// AddedOnOrAfter when polling so paging stays stable.
    /// </summary>
    public bool OrderByDateAdded { get; set; } = false;
}
