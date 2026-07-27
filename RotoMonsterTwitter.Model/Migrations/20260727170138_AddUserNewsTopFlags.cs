using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddUserNewsTopFlags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsNews",
                table: "TweetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsTop",
                table: "TweetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_TweetUsers_IsNews",
                table: "TweetUsers",
                column: "IsNews");

            migrationBuilder.CreateIndex(
                name: "IX_TweetUsers_IsTop",
                table: "TweetUsers",
                column: "IsTop");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TweetUsers_IsNews",
                table: "TweetUsers");

            migrationBuilder.DropIndex(
                name: "IX_TweetUsers_IsTop",
                table: "TweetUsers");

            migrationBuilder.DropColumn(
                name: "IsNews",
                table: "TweetUsers");

            migrationBuilder.DropColumn(
                name: "IsTop",
                table: "TweetUsers");
        }
    }
}
