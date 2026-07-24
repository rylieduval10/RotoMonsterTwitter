using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/processing")]
public class ProcessingController : ControllerBase
{
    private readonly ITweetProcessingService _processing;

    public ProcessingController(ITweetProcessingService processing)
        => _processing = processing;

    /// <summary>How much is left to process, and how many matches exist.</summary>
    [HttpGet("status")]
    public async Task<IActionResult> Status(CancellationToken ct)
        => Ok(await _processing.GetStatusAsync(ct));

    /// <summary>
    /// Process unprocessed tweets. Pass reprocessAll=true to rescan everything,
    /// which is what you want after changing the keyword list.
    /// </summary>
    [HttpPost("run")]
    public async Task<IActionResult> Run([FromQuery] int batchSize = 500,
        [FromQuery] bool reprocessAll = false, CancellationToken ct = default)
        => Ok(await _processing.ProcessAsync(batchSize, reprocessAll, ct));
}
