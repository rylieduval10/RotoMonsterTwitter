using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/lists")]
public class ListsController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public ListsController(TwitterDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken ct)
        => Ok(await _db.TwitterLists.OrderBy(l => l.ListId).ToListAsync(ct));

    [HttpPost]
    public async Task<IActionResult> Save(
        [FromBody] TwitterList list, CancellationToken ct)
    {
        if (list.ListId <= 0)
        {
            return BadRequest(new { error = "ListId is required." });
        }

        var existing = await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == list.ListId, ct);

        if (existing == null)
        {
            _db.TwitterLists.Add(list);
        }
        else
        {
            existing.SportId = list.SportId;
            existing.Name = list.Name;
            existing.IsActive = list.IsActive;
        }

        await _db.SaveChangesAsync(ct);

        return Ok(await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == list.ListId, ct));
    }

    /// <summary>Reset a list's cursor so the next pull starts from scratch.</summary>
    [HttpPost("{listId:long}/reset")]
    public async Task<IActionResult> Reset(long listId, CancellationToken ct)
    {
        var list = await _db.TwitterLists
            .FirstOrDefaultAsync(l => l.ListId == listId, ct);

        if (list == null)
        {
            return NotFound(new { error = $"No list with id {listId}." });
        }

        list.LastFetchedUnix = 0;
        await _db.SaveChangesAsync(ct);

        return Ok(list);
    }
}
