using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/keywords")]
public class KeywordsController : ControllerBase
{
    private readonly TwitterDbContext _db;

    public KeywordsController(TwitterDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? category,
        CancellationToken ct = default)
    {
        var query = _db.TwitterKeywords.AsQueryable();

        if (!string.IsNullOrWhiteSpace(category))
        {
            query = query.Where(k => k.Category.ToLower() == category.ToLower());
        }

        return Ok(await query.OrderBy(k => k.Id).ToListAsync(ct));
    }

    /// <summary>
    /// Add or update a keyword. NormalizedKeyword is derived here so callers
    /// never have to think about it.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Save([FromBody] TwitterKeyword keyword,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(keyword.Keyword))
        {
            return BadRequest(new { error = "Keyword text is required." });
        }

        keyword.NormalizedKeyword = TextNormalizer.NormalizeTerm(keyword.Keyword);

        if (string.IsNullOrEmpty(keyword.NormalizedKeyword))
        {
            return BadRequest(new { error = "Keyword contains nothing matchable." });
        }

        var existing = keyword.Id > 0
            ? await _db.TwitterKeywords.FirstOrDefaultAsync(k => k.Id == keyword.Id, ct)
            : null;

        if (existing == null)
        {
            if (keyword.Id <= 0)
            {
                var maxId = await _db.TwitterKeywords.MaxAsync(k => (int?)k.Id, ct) ?? 0;
                keyword.Id = maxId + 1;
            }

            _db.TwitterKeywords.Add(keyword);
        }
        else
        {
            existing.Keyword = keyword.Keyword;
            existing.NormalizedKeyword = keyword.NormalizedKeyword;
            existing.Category = keyword.Category;
            existing.Weight = keyword.Weight;
            existing.IsActive = keyword.IsActive;
        }

        await _db.SaveChangesAsync(ct);

        return Ok(await _db.TwitterKeywords.FirstAsync(k => k.Id == keyword.Id, ct));
    }
}
