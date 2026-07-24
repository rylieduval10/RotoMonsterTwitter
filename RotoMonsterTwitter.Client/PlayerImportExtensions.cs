using System.Text.Json;
using RotoMonsterTwitter.Contracts.Requests;

namespace RotoMonsterTwitter.Client;

/// <summary>
/// For callers that want to build the payload here but send it themselves.
/// Guarantees the json matches what the API expects, so field names and
/// casing can't drift apart.
/// </summary>
public static class PlayerImportExtensions
{
    private static readonly JsonSerializerOptions Compact = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private static readonly JsonSerializerOptions Indented = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    /// <summary>
    /// Serialize an import payload. POST the result to /api/import/players
    /// with the X-API-Key header.
    /// </summary>
    public static string RenderAsJson(this PlayerImportRequest request,
        bool indented = false)
        => JsonSerializer.Serialize(request, indented ? Indented : Compact);
}
