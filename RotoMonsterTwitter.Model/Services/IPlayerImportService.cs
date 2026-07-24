using RotoMonsterTwitter.Model.Requests;
using RotoMonsterTwitter.Model.Results;

namespace RotoMonsterTwitter.Model.Services;

public interface IPlayerImportService
{
    Task<ImportResult> ImportAsync(PlayerImportRequest request,
        CancellationToken ct = default);
}
