using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddDateAddedIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Tweets_DateAdded",
                table: "Tweets",
                column: "DateAdded");

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_SportId_DateAdded",
                table: "Tweets",
                columns: new[] { "SportId", "DateAdded" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Tweets_DateAdded",
                table: "Tweets");

            migrationBuilder.DropIndex(
                name: "IX_Tweets_SportId_DateAdded",
                table: "Tweets");
        }
    }
}
