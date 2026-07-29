using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/ai")]
public class AiController : ControllerBase
{
    private readonly IAiAnalysisService _ai;

    public AiController(IAiAnalysisService ai) => _ai = ai;

    /// <summary>
    /// Summarize a tweet for the Auto Fill button. Returns the text; the caller
    /// decides what to do with it (drop into the news box).
    /// </summary>
    [HttpPost("analyze")]
    public async Task<IActionResult> Analyze(
        [FromBody] AnalyzeTweetRequest request, CancellationToken ct)
        => Ok(await _ai.SummarizeAsync(request.Text, request.TweetId, ct));
}
