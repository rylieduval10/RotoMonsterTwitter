using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddKeywordProcessing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ProcessedAt",
                table: "Tweets",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TwitterKeywords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false),
                    Keyword = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    NormalizedKeyword = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Category = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Weight = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterKeywords", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TweetKeywords",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    KeywordId = table.Column<int>(type: "integer", nullable: false),
                    Occurrences = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetKeywords", x => new { x.TweetId, x.KeywordId });
                    table.ForeignKey(
                        name: "FK_TweetKeywords_Tweets_TweetId",
                        column: x => x.TweetId,
                        principalTable: "Tweets",
                        principalColumn: "TweetId",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TweetKeywords_TwitterKeywords_KeywordId",
                        column: x => x.KeywordId,
                        principalTable: "TwitterKeywords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_ProcessedAt",
                table: "Tweets",
                column: "ProcessedAt");

            migrationBuilder.CreateIndex(
                name: "IX_TweetKeywords_KeywordId",
                table: "TweetKeywords",
                column: "KeywordId");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterKeywords_Category",
                table: "TwitterKeywords",
                column: "Category");

            migrationBuilder.CreateIndex(
                name: "IX_TwitterKeywords_NormalizedKeyword",
                table: "TwitterKeywords",
                column: "NormalizedKeyword");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TweetKeywords");

            migrationBuilder.DropTable(
                name: "TwitterKeywords");

            migrationBuilder.DropIndex(
                name: "IX_Tweets_ProcessedAt",
                table: "Tweets");

            migrationBuilder.DropColumn(
                name: "ProcessedAt",
                table: "Tweets");
        }
    }
}
