#!/usr/bin/env bash
#
# RotoMonsterTwitter - throwaway console app that calls every client method
# against a running API, so the JSON round-trip gets proven end to end.
#
# Run from the solution root, with the API already running.
#
set -euo pipefail

if [ ! -f RotoMonsterTwitter.sln ] && [ ! -f RotoMonsterTwitter.slnx ]; then
  echo "ERROR: run this from the folder containing the solution file" >&2
  exit 1
fi

if [ ! -d RotoMonsterTwitter.ClientTest ]; then
  echo "Creating console project..."
  dotnet new console -n RotoMonsterTwitter.ClientTest >/dev/null
  dotnet sln add RotoMonsterTwitter.ClientTest >/dev/null
  dotnet add RotoMonsterTwitter.ClientTest reference RotoMonsterTwitter.Client >/dev/null
fi

echo "Writing test program..."

cat > RotoMonsterTwitter.ClientTest/Program.cs <<'CSEOF'
using RotoMonsterTwitter.Client;
using RotoMonsterTwitter.Model.Requests;

var baseUrl = args.Length > 0 ? args[0] : "http://localhost:5080";
var client = new RotoMonsterTwitterClient(baseUrl);

var failures = 0;

void Check(string label, bool ok, string? detail = null)
{
    Console.WriteLine($"  [{(ok ? "PASS" : "FAIL")}] {label}"
        + (detail is null ? "" : $"  -> {detail}"));
    if (!ok) failures++;
}

Console.WriteLine($"Testing client against {baseUrl}");
Console.WriteLine();

// ---------------------------------------------------------------- GetTweets
Console.WriteLine("GetTweetsBySportAsync(1, 3)");

var bySport = await client.GetTweetsBySportAsync(1, 3);

Check("call succeeded", bySport.Success, bySport.ErrorMessage);
Check("returned tweets", bySport.Tweets.Count > 0, $"count={bySport.Tweets.Count}");
Check("total count populated", bySport.TotalCount > 0, $"total={bySport.TotalCount}");

if (bySport.Tweets.Count == 0)
{
    Console.WriteLine();
    Console.WriteLine("No tweets stored - run the IngestJson call first.");
    return 1;
}

var first = bySport.Tweets[0];

// These are the fields that would come back null if camelCase/PascalCase
// mapping were broken, while Success still looked fine.
Check("tweetId mapped", !string.IsNullOrEmpty(first.TweetId), first.TweetId);
Check("text mapped", !string.IsNullOrEmpty(first.Text));
Check("screenUsername mapped", !string.IsNullOrEmpty(first.ScreenUsername), first.ScreenUsername);
Check("displayName mapped", !string.IsNullOrEmpty(first.DisplayName), first.DisplayName);
Check("createdDate mapped", first.CreatedDate.Year > 2000, first.CreatedDate.ToString("u"));
Check("sportId mapped", first.SportId == 1, $"sportId={first.SportId}");

var withMedia = bySport.Tweets.FirstOrDefault(t => t.Media.Count > 0);
if (withMedia != null)
{
    var m = withMedia.Media[0];
    Check("media type mapped", !string.IsNullOrEmpty(m.MediaType), m.MediaType);
    Check("media image url mapped", !string.IsNullOrEmpty(m.ImageUrl));
}
else
{
    Console.WriteLine("  [skip] no media in this page, widen maxResults to check media mapping");
}

Console.WriteLine();

// --------------------------------------------------------------- ReadTweet
Console.WriteLine($"ReadTweetAsync(\"{first.TweetId}\")");

var single = await client.ReadTweetAsync(first.TweetId);

Check("call succeeded", single.Success, single.ErrorMessage);
Check("tweet returned", single.Tweet != null);
Check("same tweet id", single.Tweet?.TweetId == first.TweetId);

Console.WriteLine();

// -------------------------------------------------------- ReadTweet (bad id)
Console.WriteLine("ReadTweetAsync(\"does-not-exist\")");

var missing = await client.ReadTweetAsync("does-not-exist");

Check("reports failure", !missing.Success);
Check("has an error message", !string.IsNullOrEmpty(missing.ErrorMessage), missing.ErrorMessage);

Console.WriteLine();

// ----------------------------------------------------------- ReadTweetList
Console.WriteLine("ReadTweetListAsync(1, 5)");

var byList = await client.ReadTweetListAsync(1, 5);

Check("call succeeded", byList.Success, byList.ErrorMessage);
Check("returned tweets", byList.Tweets.Count > 0, $"count={byList.Tweets.Count}");

Console.WriteLine();

// ------------------------------------------------------------- filter check
Console.WriteLine($"GetTweetsAsync(searchText from a stored tweet)");

var word = first.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                     .FirstOrDefault(w => w.Length > 5 && w.All(char.IsLetter));

if (word != null)
{
    var search = await client.GetTweetsAsync(new GetTweetsRequest
    {
        SearchText = word,
        MaxResults = 5
    });

    Check($"search for \"{word}\" succeeded", search.Success, search.ErrorMessage);
    Check("search found something", search.Tweets.Count > 0, $"count={search.Tweets.Count}");
}
else
{
    Console.WriteLine("  [skip] no suitable search word in the first tweet");
}

Console.WriteLine();

// ---------------------------------------------------------------- deletes
Console.WriteLine("DeleteTweetsAsync(empty request)");

var guard = await client.DeleteTweetsAsync(new DeleteTweetsRequest());

Check("refuses to delete everything", !guard.Success, guard.ErrorMessage);

Console.WriteLine();

// ------------------------------------------------------------------- post
Console.WriteLine("PostTweetAsync(\"test\")");

var post = await client.PostTweetAsync("test");

Check("stub reports not implemented", !post.Success, post.ErrorMessage);

Console.WriteLine();

// ------------------------------------------------------------- bad base url
Console.WriteLine("Unreachable host handling");

var broken = new RotoMonsterTwitterClient("http://localhost:9");
var brokenResult = await broken.GetTweetsBySportAsync(1, 1);

Check("returns a result instead of throwing", !brokenResult.Success);
Check("has an error message", !string.IsNullOrEmpty(brokenResult.ErrorMessage));

Console.WriteLine();
Console.WriteLine(failures == 0
    ? "All checks passed."
    : $"{failures} check(s) failed.");

return failures == 0 ? 0 : 1;
CSEOF

echo ""
echo "Building..."
echo ""
dotnet build RotoMonsterTwitter.ClientTest

cat <<'MSGEOF'

==================================================================
Done. With the API running in another terminal:

  dotnet run --project RotoMonsterTwitter.ClientTest

Or against a different url:

  dotnet run --project RotoMonsterTwitter.ClientTest -- http://localhost:5098

When you're finished with it:

  dotnet sln remove RotoMonsterTwitter.ClientTest
  rm -rf RotoMonsterTwitter.ClientTest
==================================================================
MSGEOF
