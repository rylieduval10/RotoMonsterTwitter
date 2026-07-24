using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayersAndTeams : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TwitterPlayers",
                columns: table => new
                {
                    PlayerId = table.Column<int>(type: "integer", nullable: false),
                    SportId = table.Column<int>(type: "integer", nullable: false),
                    FirstName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    LastName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    NormalizedFullName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    NormalizedLastName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    TeamId = table.Column<int>(type: "integer", nullable: true),
                    FullNameOnly = table.Column<bool>(type: "boolean", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterPlayers", x => x.PlayerId);
                });

            migrationBuilder.CreateTable(
                name: "TwitterTeams",
                columns: table => new
                {
                    TeamId = table.Column<int>(type: "integer", nullable: false),
                    SportId = table.Column<int>(type: "integer", nullable: false),
                    City = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Abbreviation = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    NormalizedFullName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    NormalizedName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    NormalizedAbbreviation = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterTeams", x => x.TeamId);
                });

            migrationBuilder.CreateTable(
                name: "TweetPlayers",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    PlayerId = table.Column<int>(type: "integer", nullable: false),
                    MatchType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Confidence = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false),
                    Occurrences = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetPlayers", x => new { x.TweetId, x.PlayerId });
                    table.ForeignKey(
                        name: "FK_TweetPlayers_Tweets_TweetId",
                        column: x => x.TweetId,
                        principalTable: "Tweets",
                        principalColumn: "TweetId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TweetPlayers_TwitterPlayers_PlayerId",
                        column: x => x.PlayerId,
                        principalTable: "TwitterPlayers",
                        principalColumn: "PlayerId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TwitterPlayerAliases",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    PlayerId = table.Column<int>(type: "integer", nullable: false),
                    Alias = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    NormalizedAlias = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterPlayerAliases", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TwitterPlayerAliases_TwitterPlayers_PlayerId",
                        column: x => x.PlayerId,
                        principalTable: "TwitterPlayers",
                        principalColumn: "PlayerId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TweetTeams",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    TeamId = table.Column<int>(type: "integer", nullable: false),
                    MatchType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Confidence = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false),
                    Occurrences = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetTeams", x => new { x.TweetId, x.TeamId });
                    table.ForeignKey(
                        name: "FK_TweetTeams_Tweets_TweetId",
                        column: x => x.TweetId,
                        principalTable: "Tweets",
                        principalColumn: "TweetId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TweetTeams_TwitterTeams_TeamId",
                        column: x => x.TeamId,
                        principalTable: "TwitterTeams",
                        principalColumn: "TeamId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TwitterTeamAliases",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    TeamId = table.Column<int>(type: "integer", nullable: false),
                    Alias = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    NormalizedAlias = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterTeamAliases", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TwitterTeamAliases_TwitterTeams_TeamId",
                        column: x => x.TeamId,
                        principalTable: "TwitterTeams",
                        principalColumn: "TeamId",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TweetPlayers_Confidence",
                table: "TweetPlayers",
                column: "Confidence");

            migrationBuilder.CreateIndex(
                name: "IX_TweetPlayers_PlayerId",
                table: "TweetPlayers",
                column: "PlayerId");

            migrationBuilder.CreateIndex(
                name: "IX_TweetTeams_TeamId",
                table: "TweetTeams",
                column: "TeamId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayerAliases_NormalizedAlias",
                table: "TwitterPlayerAliases",
                column: "NormalizedAlias");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayerAliases_PlayerId",
                table: "TwitterPlayerAliases",
                column: "PlayerId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayers_NormalizedLastName",
                table: "TwitterPlayers",
                column: "NormalizedLastName");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayers_SportId",
                table: "TwitterPlayers",
                column: "SportId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayers_TeamId",
                table: "TwitterPlayers",
                column: "TeamId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterTeamAliases_NormalizedAlias",
                table: "TwitterTeamAliases",
                column: "NormalizedAlias");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterTeamAliases_TeamId",
                table: "TwitterTeamAliases",
                column: "TeamId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterTeams_SportId",
                table: "TwitterTeams",
                column: "SportId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TweetPlayers");

            migrationBuilder.DropTable(
                name: "TweetTeams");

            migrationBuilder.DropTable(
                name: "TwitterPlayerAliases");

            migrationBuilder.DropTable(
                name: "TwitterTeamAliases");

            migrationBuilder.DropTable(
                name: "TwitterPlayers");

            migrationBuilder.DropTable(
                name: "TwitterTeams");
        }
    }
}
