using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RotoMonsterTwitter.API.Middleware;
using RotoMonsterTwitter.Model.Configuration;
using RotoMonsterTwitter.Model.Data;
using RotoMonsterTwitter.Model.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<TwitterDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("TwitterDb")));

builder.Services.Configure<TwitterApiOptions>(
    builder.Configuration.GetSection(TwitterApiOptions.SectionName));

builder.Services.Configure<TwitterPostOptions>(
    builder.Configuration.GetSection(TwitterPostOptions.SectionName));

builder.Services.Configure<ApiKeyOptions>(
    builder.Configuration.GetSection(ApiKeyOptions.SectionName));

builder.Services.AddHttpClient<ITwitterApiService, TwitterApiService>((sp, client) =>
{
    var options = sp.GetRequiredService<IOptions<TwitterApiOptions>>().Value;
    client.DefaultRequestHeaders.Add("X-API-Key", options.ApiKey);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(options.UserAgent);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddHttpClient<ITwitterPosterService, TwitterPosterService>(
    client => client.Timeout = TimeSpan.FromSeconds(30));

builder.Services.AddScoped<ITweetService, TweetService>();
builder.Services.AddScoped<ITweetIngestService, TweetIngestService>();
builder.Services.AddScoped<ITweetProcessingService, TweetProcessingService>();
builder.Services.AddScoped<IPlayerImportService, PlayerImportService>();

builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseMiddleware<ApiKeyMiddleware>();

app.MapControllers();

app.MapGet("/health", async (TwitterDbContext db) =>
{
    var canConnect = await db.Database.CanConnectAsync();
    return Results.Ok(new { database = canConnect ? "connected" : "unreachable" });
});

app.Run();
