using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/users")]
public class UsersController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public UsersController(TwitterDbContext db) => _db = db;

    /// <summary>
    /// Browse stored users so you can decide who to flag. Filter on either
    /// flag, or search on handle / display name.
    /// </summary>
    [HttpPost("GetUsers")]
    public async Task<IActionResult> GetUsers([FromBody] GetUsersRequest request,
        CancellationToken ct = default)
    {
        request ??= new GetUsersRequest();

        var query = _db.TweetUsers.AsQueryable();

        if (request.IsNews.HasValue)
            query = query.Where(u => u.IsNews == request.IsNews.Value);

        if (request.IsTop.HasValue)
            query = query.Where(u => u.IsTop == request.IsTop.Value);

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var term = $"%{request.SearchText}%";
            query = query.Where(u => EF.Functions.ILike(u.ScreenUsername, term)
                                  || EF.Functions.ILike(u.DisplayName, term));
        }

        var total = await query.CountAsync(ct);

        var rows = await query
            .OrderBy(u => u.ScreenUsername)
            .Skip(Math.Max(0, request.Skip))
            .Take(Math.Clamp(request.MaxResults, 1, 1000))
            .ToListAsync(ct);

        return Ok(new GetUsersResult
        {
            TotalCount = total,
            Users = rows.Select(Map).ToList()
        });
    }

    /// <summary>
    /// Set IsNews / IsTop on specific users. Only the users you send are
    /// touched, and a null flag leaves that flag exactly as it was.
    /// </summary>
    [HttpPost("SetFlags")]
    public async Task<IActionResult> SetFlags([FromBody] SetUserFlagsRequest request,
        CancellationToken ct = default)
    {
        if (request?.Users == null || request.Users.Count == 0)
        {
            return BadRequest(new SetUserFlagsResult
            {
                Success = false,
                ErrorMessage = "Send at least one user."
            });
        }

        var handles = request.Users
            .Where(u => !string.IsNullOrWhiteSpace(u.ScreenUsername))
            .Select(u => u.ScreenUsername!.TrimStart('@').ToLower())
            .ToList();

        var ids = request.Users
            .Where(u => !string.IsNullOrWhiteSpace(u.TwitterUserId))
            .Select(u => u.TwitterUserId!)
            .ToList();

        var matched = await _db.TweetUsers
            .Where(u => handles.Contains(u.ScreenUsername.ToLower())
                     || ids.Contains(u.TwitterUserId))
            .ToListAsync(ct);

        var byHandle = matched
            .GroupBy(u => u.ScreenUsername.ToLower())
            .ToDictionary(g => g.Key, g => g.First());

        var byId = matched
            .GroupBy(u => u.TwitterUserId)
            .ToDictionary(g => g.Key, g => g.First());

        var result = new SetUserFlagsResult();

        foreach (var update in request.Users)
        {
            TweetUser? user = null;

            if (!string.IsNullOrWhiteSpace(update.ScreenUsername))
                byHandle.TryGetValue(update.ScreenUsername.TrimStart('@').ToLower(), out user);

            if (user == null && !string.IsNullOrWhiteSpace(update.TwitterUserId))
                byId.TryGetValue(update.TwitterUserId, out user);

            if (user == null)
            {
                result.NotFound.Add(update.ScreenUsername
                                    ?? update.TwitterUserId
                                    ?? "(no identifier)");
                continue;
            }

            if (update.IsNews.HasValue) user.IsNews = update.IsNews.Value;
            if (update.IsTop.HasValue) user.IsTop = update.IsTop.Value;

            result.Updated++;
            result.Users.Add(Map(user));
        }

        await _db.SaveChangesAsync(ct);

        return Ok(result);
    }

    private static TweetUserResult Map(TweetUser u) => new TweetUserResult
    {
        TwitterUserId = u.TwitterUserId,
        ScreenUsername = u.ScreenUsername,
        DisplayName = u.DisplayName,
        ImageUrl = u.ImageUrl,
        IsVerified = u.IsVerified,
        IsBlueVerified = u.IsBlueVerified,
        IsNews = u.IsNews,
        IsTop = u.IsTop,
        LastSeenAt = u.LastSeenAt
    };
}
