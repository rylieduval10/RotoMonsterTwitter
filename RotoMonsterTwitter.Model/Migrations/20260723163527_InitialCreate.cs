using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TweetUsers",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    TwitterUserId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    ScreenUsername = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IsVerified = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TweetUsers", x => x.Id);
                    table.UniqueConstraint("AK_TweetUsers_TwitterUserId", x => x.TwitterUserId);
                });

            migrationBuilder.CreateTable(
                name: "TwitterLists",
                columns: table => new
                {
                    ListId = table.Column<long>(type: "bigint", nullable: false),
                    SportId = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    LastFetchedUnix = table.Column<long>(type: "bigint", nullable: false),
                    LastFetchedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastTweetCount = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TwitterLists", x => x.ListId);
                });

            migrationBuilder.CreateTable(
                name: "Tweets",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    TwitterUserId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    SportId = table.Column<int>(type: "integer", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RetweetDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DateAdded = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsRetweet = table.Column<bool>(type: "boolean", nullable: true),
                    IsSourceTweet = table.Column<bool>(type: "boolean", nullable: true),
                    RetweetUserScreenName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Text = table.Column<string>(type: "text", nullable: false),
                    RetweetCount = table.Column<int>(type: "integer", nullable: true),
                    Followers = table.Column<int>(type: "integer", nullable: true),
                    SourceTweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    SourceTweetUserScreenName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tweets", x => x.TweetId);
                    table.ForeignKey(
                        name: "FK_Tweets_TweetUsers_TwitterUserId",
                        column: x => x.TwitterUserId,
                        principalTable: "TweetUsers",
                        principalColumn: "TwitterUserId",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TweetImages",
                columns: table => new
                {
                    TweetId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    DisplayOrder = table.Column<short>(type: "smallint", nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false)
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

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_CreatedDate",
                table: "Tweets",
                column: "CreatedDate");

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_SportId_CreatedDate",
                table: "Tweets",
                columns: new[] { "SportId", "CreatedDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Tweets_TwitterUserId",
                table: "Tweets",
                column: "TwitterUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TweetUsers_ScreenUsername",
                table: "TweetUsers",
                column: "ScreenUsername",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TweetUsers_TwitterUserId",
                table: "TweetUsers",
                column: "TwitterUserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TwitterLists_SportId",
                table: "TwitterLists",
                column: "SportId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TweetImages");

            migrationBuilder.DropTable(
                name: "TwitterLists");

            migrationBuilder.DropTable(
                name: "Tweets");

            migrationBuilder.DropTable(
                name: "TweetUsers");
        }
    }
}
