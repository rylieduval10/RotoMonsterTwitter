namespace RotoMonsterTwitter.Contracts.Results;

public class GetUsersResult : BaseResult
{
    public int TotalCount { get; set; }
    public List<TweetUserResult> Users { get; set; } = new();
}

public class TweetUserResult
{
    public string TwitterUserId { get; set; } = "";
    public string ScreenUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string ImageUrl { get; set; } = "";
    public bool IsVerified { get; set; }
    public bool IsBlueVerified { get; set; }
    public bool IsNews { get; set; }
    public bool IsTop { get; set; }
    public DateTime? LastSeenAt { get; set; }
}
