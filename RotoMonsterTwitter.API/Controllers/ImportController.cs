using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/import")]
public class ImportController : ControllerBase
{
    private readonly IPlayerImportService _import;

    public ImportController(IPlayerImportService import) => _import = import;

    /// <summary>
    /// Replace the player and team pool for a sport. Send the complete set;
    /// anything missing from it is dropped.
    /// </summary>
    [HttpPost("players")]
    public async Task<IActionResult> Players([FromBody] PlayerImportRequest request,
        CancellationToken ct)
        => Ok(await _import.ImportAsync(request, ct));
}
