namespace RotoMonsterTwitter.Model.Entities;

public class TweetUser
{
    public long Id { get; set; }
    public string TwitterUserId { get; set; } = "";
    public string ScreenUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string ImageUrl { get; set; } = "";

    public bool IsVerified { get; set; }
    public bool IsBlueVerified { get; set; }
    public string? VerifiedType { get; set; }

    public DateTime? LastSeenAt { get; set; }
}
