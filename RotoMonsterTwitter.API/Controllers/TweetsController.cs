using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/tweets")]
public class TweetsController : ControllerBase
{
    private readonly ITweetService _tweets;
    private readonly ITweetIngestService _ingest;

    public TweetsController(ITweetService tweets, ITweetIngestService ingest)
    {
        _tweets = tweets;
        _ingest = ingest;
    }

    [HttpPost("GetTweets")]
    public async Task<IActionResult> GetTweets([FromBody] GetTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.GetTweetsAsync(request, ct));

    [HttpGet("ReadTweet/{tweetId}")]
    public async Task<IActionResult> ReadTweet(string tweetId, CancellationToken ct)
        => Ok(await _tweets.ReadTweetAsync(tweetId, ct));

    [HttpGet("ReadTweetList/{listId:long}")]
    public async Task<IActionResult> ReadTweetList(long listId, [FromQuery] int maxResults = 100, CancellationToken ct = default)
        => Ok(await _tweets.ReadTweetListAsync(listId, maxResults, ct));

    [HttpPost("DeleteTweets")]
    public async Task<IActionResult> DeleteTweets([FromBody] DeleteTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.DeleteTweetsAsync(request, ct));

    [HttpPost("Ingest/{listId:long}")]
    public async Task<IActionResult> Ingest(long listId, CancellationToken ct)
        => Ok(await _ingest.IngestListAsync(listId, ct));

    /// <summary>
    /// Dev-only. POST a raw twitterapi.io response body and store it as if it
    /// had been fetched. Lets the parse/store path be exercised without a list id.
    /// </summary>
    [HttpPost("IngestJson/{listId:long}")]
    public async Task<IActionResult> IngestJson(long listId, CancellationToken ct)
    {
        if (!HttpContext.RequestServices
                .GetRequiredService<IWebHostEnvironment>().IsDevelopment())
        {
            return NotFound();
        }

        using var reader = new StreamReader(Request.Body);
        var json = await reader.ReadToEndAsync(ct);

        if (string.IsNullOrWhiteSpace(json))
        {
            return BadRequest(new { error = "Empty request body." });
        }

        return Ok(await _ingest.IngestJsonAsync(listId, json, ct));
    }
}
