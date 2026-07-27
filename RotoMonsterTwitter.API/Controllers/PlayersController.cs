using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/players")]
public class PlayersController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public PlayersController(TwitterDbContext db) => _db = db;

    /// <summary>The status vocabulary. Inactive rows are returned too, flagged.</summary>
    [HttpGet("StatusTypes")]
    public async Task<IActionResult> StatusTypes(CancellationToken ct = default)
    {
        var rows = await _db.PlayerStatusTypes
            .OrderBy(s => s.Id)
            .ToListAsync(ct);

        return Ok(new GetPlayerStatusTypesResult
        {
            StatusTypes = rows.Select(s => new PlayerStatusTypeResult
            {
                Id = s.Id,
                Title = s.Title,
                IsActive = s.IsActive
            }).ToList()
        });
    }

    /// <summary>
    /// Browse stored players so you can find ids and see current statuses.
    /// </summary>
    [HttpPost("GetPlayers")]
    public async Task<IActionResult> GetPlayers([FromBody] GetPlayersRequest request,
        CancellationToken ct = default)
    {
        request ??= new GetPlayersRequest();

        var query = _db.TwitterPlayers.Include(p => p.Aliases).AsQueryable();

        if (request.SportId.HasValue)
            query = query.Where(p => p.SportId == request.SportId.Value);

        if (request.PlayerStatusTypeId.HasValue)
            query = query.Where(p => p.PlayerStatusTypeId == request.PlayerStatusTypeId.Value);

        if (request.HasStatus.HasValue)
        {
            query = request.HasStatus.Value
                ? query.Where(p => p.PlayerStatusTypeId != null)
                : query.Where(p => p.PlayerStatusTypeId == null);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var term = $"%{request.SearchText}%";
            query = query.Where(p => EF.Functions.ILike(p.FirstName, term)
                                  || EF.Functions.ILike(p.LastName, term));
        }

        var total = await query.CountAsync(ct);

        var rows = await query
            .OrderBy(p => p.LastName).ThenBy(p => p.FirstName)
            .Skip(Math.Max(0, request.Skip))
            .Take(Math.Clamp(request.MaxResults, 1, 1000))
            .ToListAsync(ct);

        var titles = await StatusTitlesAsync(rows, ct);

        return Ok(new GetPlayersResult
        {
            TotalCount = total,
            Players = rows.Select(p => Map(p, titles)).ToList()
        });
    }

    /// <summary>
    /// Set the status on specific players. Only the players you send are
    /// touched. A null PlayerStatusTypeId clears the status.
    /// </summary>
    [HttpPost("SetStatus")]
    public async Task<IActionResult> SetStatus([FromBody] SetPlayerStatusRequest request,
        CancellationToken ct = default)
    {
        if (request?.Players == null || request.Players.Count == 0)
        {
            return BadRequest(new SetPlayerStatusResult
            {
                Success = false,
                ErrorMessage = "Send at least one player."
            });
        }

        var result = new SetPlayerStatusResult();

        var wantedStatusIds = request.Players
            .Where(p => p.PlayerStatusTypeId.HasValue)
            .Select(p => p.PlayerStatusTypeId!.Value)
            .Distinct()
            .ToList();

        var validStatusIds = await _db.PlayerStatusTypes
            .Where(s => wantedStatusIds.Contains(s.Id))
            .Select(s => s.Id)
            .ToListAsync(ct);

        var validSet = validStatusIds.ToHashSet();

        var playerIds = request.Players.Select(p => p.PlayerId).Distinct().ToList();

        var players = await _db.TwitterPlayers
            .Include(p => p.Aliases)
            .Where(p => playerIds.Contains(p.PlayerId))
            .ToListAsync(ct);

        var byId = players.ToDictionary(p => p.PlayerId);

        foreach (var update in request.Players)
        {
            if (!byId.TryGetValue(update.PlayerId, out var player))
            {
                result.NotFound.Add(update.PlayerId);
                continue;
            }

            if (update.PlayerStatusTypeId.HasValue
                && !validSet.Contains(update.PlayerStatusTypeId.Value))
            {
                if (!result.InvalidStatusTypeIds.Contains(update.PlayerStatusTypeId.Value))
                    result.InvalidStatusTypeIds.Add(update.PlayerStatusTypeId.Value);
                continue;
            }

            player.PlayerStatusTypeId = update.PlayerStatusTypeId;
            result.Updated++;
        }

        await _db.SaveChangesAsync(ct);

        var touched = players
            .Where(p => request.Players.Any(u => u.PlayerId == p.PlayerId))
            .ToList();

        var titles = await StatusTitlesAsync(touched, ct);
        result.Players = touched.Select(p => Map(p, titles)).ToList();

        return Ok(result);
    }

    private async Task<Dictionary<int, string>> StatusTitlesAsync(
        List<TwitterPlayer> players, CancellationToken ct)
    {
        var ids = players
            .Where(p => p.PlayerStatusTypeId.HasValue)
            .Select(p => p.PlayerStatusTypeId!.Value)
            .Distinct()
            .ToList();

        if (ids.Count == 0) return new Dictionary<int, string>();

        return await _db.PlayerStatusTypes
            .Where(s => ids.Contains(s.Id))
            .ToDictionaryAsync(s => s.Id, s => s.Title, ct);
    }

    private static TwitterPlayerResult Map(TwitterPlayer p, Dictionary<int, string> titles)
    {
        string? title = null;
        if (p.PlayerStatusTypeId.HasValue)
            titles.TryGetValue(p.PlayerStatusTypeId.Value, out title);

        return new TwitterPlayerResult
        {
            PlayerId = p.PlayerId,
            SportId = p.SportId,
            FirstName = p.FirstName,
            LastName = p.LastName,
            TeamId = p.TeamId,
            FullNameOnly = p.FullNameOnly,
            IsActive = p.IsActive,
            PlayerStatusTypeId = p.PlayerStatusTypeId,
            PlayerStatusTitle = title,
            Aliases = p.Aliases.Select(a => a.Alias).ToList()
        };
    }
}
