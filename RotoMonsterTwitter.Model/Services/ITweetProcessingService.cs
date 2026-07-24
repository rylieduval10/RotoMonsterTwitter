using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface ITweetProcessingService
{
    /// <summary>
    /// Extract keywords from stored tweets. By default only touches tweets that
    /// haven't been processed; reprocessAll rescans everything, which is what
    /// you want after adding keywords.
    /// </summary>
    Task<ProcessTweetsResult> ProcessAsync(int batchSize = 500,
        bool reprocessAll = false, CancellationToken ct = default);

    Task<ProcessTweetsResult> GetStatusAsync(CancellationToken ct = default);
}
