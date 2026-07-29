using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface IAiAnalysisService
{
    Task<AnalyzeTweetResult> SummarizeAsync(
        string text, string? tweetId = null, CancellationToken ct = default);
}
