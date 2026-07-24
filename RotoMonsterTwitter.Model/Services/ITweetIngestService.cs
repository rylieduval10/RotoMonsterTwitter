using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetIngestService
{
    /// <summary>Fetch from twitterapi.io and store.</summary>
    Task<IngestResult> IngestListAsync(long listId, CancellationToken ct = default);

    /// <summary>
    /// Store from a raw twitterapi.io response body already in hand.
    /// Used for testing the parse/store path without an HTTP call.
    /// </summary>
    Task<IngestResult> IngestJsonAsync(long listId, string json, CancellationToken ct = default);
}
