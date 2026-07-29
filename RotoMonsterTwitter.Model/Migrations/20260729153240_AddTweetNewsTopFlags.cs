using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddTweetNewsTopFlags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsNews",
                table: "Tweets",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsTop",
                table: "Tweets",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_IsNews",
                table: "Tweets",
                column: "IsNews");

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_IsTop",
                table: "Tweets",
                column: "IsTop");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Tweets_IsNews",
                table: "Tweets");

            migrationBuilder.DropIndex(
                name: "IX_Tweets_IsTop",
                table: "Tweets");

            migrationBuilder.DropColumn(
                name: "IsNews",
                table: "Tweets");

            migrationBuilder.DropColumn(
                name: "IsTop",
                table: "Tweets");
        }
    }
}
