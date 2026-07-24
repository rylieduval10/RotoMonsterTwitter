using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface IPlayerImportService
{
    Task<ImportResult> ImportAsync(PlayerImportRequest request,
        CancellationToken ct = default);
}
