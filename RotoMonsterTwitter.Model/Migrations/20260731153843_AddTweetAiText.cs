using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddTweetAiText : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AiText",
                table: "Tweets",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AiText",
                table: "Tweets");
        }
    }
}
