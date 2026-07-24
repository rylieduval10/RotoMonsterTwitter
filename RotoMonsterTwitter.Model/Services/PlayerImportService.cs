using Microsoft.EntityFrameworkCore;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Entities;
using RotoMonsterTwitter.Contracts.Requests;
using RotoMonsterTwitter.Contracts.Results;

namespace RotoMonsterTwitter.Model.Services;

/// <summary>
/// Replaces the player and team pool for one sport. Whole-set replacement
/// rather than a diff, so the sender doesn't have to track changes and a
/// retired player disappears without anyone having to say so.
/// </summary>
public class PlayerImportService : IPlayerImportService
{
    private readonly TwitterDbContext _db;

    public PlayerImportService(TwitterDbContext db) => _db = db;

    public async Task<ImportResult> ImportAsync(PlayerImportRequest request,
        CancellationToken ct = default)
    {
        var result = new ImportResult { SportId = request.SportId };

        if (request.SportId <= 0)
        {
            result.Success = false;
            result.ErrorMessage = "SportId is required.";
            return result;
        }

        if (request.Players.Count == 0 && request.Teams.Count == 0)
        {
            result.Success = false;
            result.ErrorMessage = "Nothing to import. Refusing to wipe the pool.";
            return result;
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(ct);

        // Teams first - players reference them.
        if (request.Teams.Count > 0)
        {
            await _db.TwitterTeams
                .Where(t => t.SportId == request.SportId)
                .ExecuteDeleteAsync(ct);

            foreach (var incoming in request.Teams)
            {
                if (incoming.TeamId <= 0 || string.IsNullOrWhiteSpace(incoming.Name))
                {
                    result.Skipped++;
                    continue;
                }

                var team = new TwitterTeam
                {
                    TeamId = incoming.TeamId,
                    SportId = request.SportId,
                    City = incoming.City,
                    Name = incoming.Name,
                    Abbreviation = incoming.Abbreviation,
                    NormalizedFullName = TextNormalizer.NormalizeTerm(
                        $"{incoming.City} {incoming.Name}"),
                    NormalizedName = TextNormalizer.NormalizeTerm(incoming.Name),
                    NormalizedAbbreviation = TextNormalizer.NormalizeTerm(
                        incoming.Abbreviation)
                };

                foreach (var alias in incoming.Aliases.Distinct())
                {
                    var normalized = TextNormalizer.NormalizeTerm(alias);
                    if (string.IsNullOrEmpty(normalized)) continue;

                    team.Aliases.Add(new TwitterTeamAlias
                    {
                        Alias = alias,
                        NormalizedAlias = normalized
                    });
                }

                _db.TwitterTeams.Add(team);
                result.TeamsImported++;
                result.TeamAliases += team.Aliases.Count;
            }
        }

        if (request.Players.Count > 0)
        {
            await _db.TwitterPlayers
                .Where(p => p.SportId == request.SportId)
                .ExecuteDeleteAsync(ct);

            foreach (var incoming in request.Players)
            {
                if (incoming.PlayerId <= 0 || string.IsNullOrWhiteSpace(incoming.LastName))
                {
                    result.Skipped++;
                    continue;
                }

                var player = new TwitterPlayer
                {
                    PlayerId = incoming.PlayerId,
                    SportId = request.SportId,
                    FirstName = incoming.FirstName,
                    LastName = incoming.LastName,
                    TeamId = incoming.TeamId,
                    FullNameOnly = incoming.FullNameOnly,
                    NormalizedFullName = TextNormalizer.NormalizeTerm(
                        $"{incoming.FirstName} {incoming.LastName}"),
                    NormalizedLastName = TextNormalizer.NormalizeTerm(incoming.LastName)
                };

                foreach (var alias in incoming.Aliases.Distinct())
                {
                    var normalized = TextNormalizer.NormalizeTerm(alias);
                    if (string.IsNullOrEmpty(normalized)) continue;

                    player.Aliases.Add(new TwitterPlayerAlias
                    {
                        Alias = alias,
                        NormalizedAlias = normalized
                    });
                }

                _db.TwitterPlayers.Add(player);
                result.PlayersImported++;
                result.PlayerAliases += player.Aliases.Count;
            }
        }

        await _db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);

        return result;
    }
}
