using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class RenameTweetImagesToTweetMedia : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TweetImages");

            migrationBuilder.CreateTable(
                name: "TweetMedia",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    DisplayOrder = table.Column<short>(type: "smallint", nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    MediaType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    VideoUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DurationMillis = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetMedia", x => new { x.TweetId, x.DisplayOrder });
                    table.ForeignKey(
                        name: "FK_TweetMedia_Tweets_TweetId",
                        column: x => x.TweetId,
                        principalTable: "Tweets",
                        principalColumn: "TweetId",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TweetMedia");

            migrationBuilder.CreateTable(
                name: "TweetImages",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    DisplayOrder = table.Column<short>(type: "smallint", nullable: false),
                    DurationMillis = table.Column<int>(type: "integer", nullable: true),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    MediaType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    VideoUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetImages", x => new { x.TweetId, x.DisplayOrder });
                    table.ForeignKey(
                        name: "FK_TweetImages_Tweets_TweetId",
                        column: x => x.TweetId,
                        principalTable: "Tweets",
                        principalColumn: "TweetId",
                        onDelete: ReferentialAction.Cascade);
                });
        }
    }
}
