using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayerStatusTypes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PlayerStatusTypeId",
                table: "TwitterPlayers",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PlayerStatusTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlayerStatusTypes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TwitterPlayers_PlayerStatusTypeId",
                table: "TwitterPlayers",
                column: "PlayerStatusTypeId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlayerStatusTypes");

            migrationBuilder.DropIndex(
                name: "IX_TwitterPlayers_PlayerStatusTypeId",
                table: "TwitterPlayers");

            migrationBuilder.DropColumn(
                name: "PlayerStatusTypeId",
                table: "TwitterPlayers");
        }
    }
}
