#!/usr/bin/env bash
#
# RotoMonsterTwitter - put the player import into the Client project, which is
# where Ken asked for it. He references the client, builds a
# PlayerImportRequest, and either calls RenderAsJson to send it himself or
# calls ImportPlayersAsync and lets the client do it.
#
# Run from the solution root.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

echo "Writing RenderAsJson helper..."

cat > RotoMonsterTwitter.Client/PlayerImportExtensions.cs <<'CSEOF'
using System.Text.Json;
using RotoMonsterTwitter.Model.Requests;

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
CSEOF

echo "Adding the import method to the client..."

python3 - <<'PYEOF'
import pathlib

p = pathlib.Path("RotoMonsterTwitter.Client/IRotoMonsterTwitterClient.cs")
text = p.read_text()

if "ImportPlayersAsync" not in text:
    text = text.replace(
        "    /// <summary>Post a tweet through the API's X credentials.</summary>",
        "    /// <summary>\n"
        "    /// Replace the player and team pool for a sport. Send the complete\n"
        "    /// set each time - anything missing from it is dropped.\n"
        "    /// </summary>\n"
        "    Task<ImportResult> ImportPlayersAsync(PlayerImportRequest request,\n"
        "        CancellationToken ct = default);\n"
        "\n"
        "    /// <summary>Post a tweet through the API's X credentials.</summary>")
    p.write_text(text)
    print("  patched IRotoMonsterTwitterClient.cs")

p = pathlib.Path("RotoMonsterTwitter.Client/RotoMonsterTwitterClient.cs")
text = p.read_text()

if "ImportPlayersAsync" not in text:
    text = text.replace(
        "    // ----------------------------------------------------------------- post",
        "    // --------------------------------------------------------------- import\n"
        "\n"
        "    public Task<ImportResult> ImportPlayersAsync(\n"
        "        PlayerImportRequest request, CancellationToken ct = default)\n"
        "        => PostAsync<PlayerImportRequest, ImportResult>(\n"
        "            \"api/import/players\", request, ct);\n"
        "\n"
        "    // ----------------------------------------------------------------- post")
    p.write_text(text)
    print("  patched RotoMonsterTwitterClient.cs")
PYEOF

echo ""
echo "Building..."
echo ""
dotnet build

cat <<'MSGEOF'

==================================================================
Done. Ken references RotoMonsterTwitter.Client and writes:

  var import = new PlayerImportRequest { SportId = 1 };

  import.Players.Add(new PlayerImport
  {
      PlayerId = 1234,
      FirstName = "Kevin",
      LastName = "Love",
      TeamId = 12,
      FullNameOnly = true
  });

  import.Teams.Add(new TeamImport
  {
      TeamId = 12,
      City = "Portland",
      Name = "Trail Blazers",
      Abbreviation = "POR",
      Aliases = { "Blazers", "Rip City" }
  });

Then either send it himself:

  string json = import.RenderAsJson();

or let the client do it:

  var client = new RotoMonsterTwitterClient(
      "https://twitter.rotomonster.com", apiKey);

  var result = await client.ImportPlayersAsync(import);

The standalone file in for-ken/ still works as a fallback if he'd
rather not take the project reference.
==================================================================
MSGEOF
