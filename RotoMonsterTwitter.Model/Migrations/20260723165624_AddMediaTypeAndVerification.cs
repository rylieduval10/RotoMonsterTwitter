using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RotoMonsterTwitter.Model.Migrations
{
    /// <inheritdoc />
    public partial class AddMediaTypeAndVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsBlueVerified",
                table: "TweetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSeenAt",
                table: "TweetUsers",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VerifiedType",
                table: "TweetUsers",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "DurationMillis",
                table: "TweetImages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MediaType",
                table: "TweetImages",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "VideoUrl",
                table: "TweetImages",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsBlueVerified",
                table: "TweetUsers");

            migrationBuilder.DropColumn(
                name: "LastSeenAt",
                table: "TweetUsers");

            migrationBuilder.DropColumn(
                name: "VerifiedType",
                table: "TweetUsers");

            migrationBuilder.DropColumn(
                name: "DurationMillis",
                table: "TweetImages");

            migrationBuilder.DropColumn(
                name: "MediaType",
                table: "TweetImages");

            migrationBuilder.DropColumn(
                name: "VideoUrl",
                table: "TweetImages");
        }
    }
}
