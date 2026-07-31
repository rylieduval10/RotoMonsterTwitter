using Microsoft.AspNetCore.Mvc;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Model.Services;

namespace RotoMonsterTwitter.API.Controllers;

[ApiController]
[Route("api/tweets")]
public class TweetsController : ControllerBase
{
    private readonly ITweetService _tweets;
    private readonly ITweetIngestService _ingest;
    private readonly ITwitterPosterService _poster;

    public TweetsController(ITweetService tweets, ITweetIngestService ingest,
        ITwitterPosterService poster)
    {
        _tweets = tweets;
        _ingest = ingest;
        _poster = poster;
    }

    [HttpPost("GetTweets")]
    public async Task<IActionResult> GetTweets(
        [FromBody] GetTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.GetTweetsAsync(request, ct));

    [HttpGet("ReadTweet/{tweetId}")]
    public async Task<IActionResult> ReadTweet(string tweetId, CancellationToken ct)
        => Ok(await _tweets.ReadTweetAsync(tweetId, ct));

    [HttpGet("ReadTweetList/{listId:long}")]
    public async Task<IActionResult> ReadTweetList(long listId,
        [FromQuery] int maxResults = 100, CancellationToken ct = default)
        => Ok(await _tweets.ReadTweetListAsync(listId, maxResults, ct));

    [HttpPost("DeleteTweets")]
    public async Task<IActionResult> DeleteTweets(
        [FromBody] DeleteTweetsRequest request, CancellationToken ct)
        => Ok(await _tweets.DeleteTweetsAsync(request, ct));

    /// <summary>Store the AI summary for a tweet so later reads return it.</summary>
    [HttpPost("SetAiText")]
    public async Task<IActionResult> SetAiText(
        [FromBody] SetAiTextRequest request, CancellationToken ct)
        => Ok(await _tweets.SetAiTextAsync(request, ct));

    [HttpPost("PostTweet")]
    public async Task<IActionResult> PostTweet(
        [FromBody] PostTweetRequest request, CancellationToken ct)
        => Ok(await _poster.PostTweetAsync(request.Text, ct));

    /// <summary>Pull new tweets for a list. This is what the monitoring app calls.</summary>
    [HttpPost("Ingest/{listId:long}")]
    public async Task<IActionResult> Ingest(long listId, CancellationToken ct)
        => Ok(await _ingest.IngestListAsync(listId, ct));

    /// <summary>Dev-only. POST a raw twitterapi.io body and store it.</summary>
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
