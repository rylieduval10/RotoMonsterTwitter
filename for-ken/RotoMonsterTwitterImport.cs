using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace SharedCS
{
    /// <summary>
    /// Builds the player and team payload for the RotoMonsterTwitter API.
    ///
    /// Fill it in, call RenderAsJson, and POST the result to:
    ///     https://twitter.rotomonster.com/api/import/players
    /// with header:
    ///     X-API-Key: your key
    ///
    /// Send the complete pool every time. The API replaces what it has for
    /// that sport rather than merging, so retired players drop off on their
    /// own and nothing has to track what changed.
    ///
    /// Example:
    ///     var import = new TwitterImport { SportId = 1 };
    ///
    ///     import.Players.Add(new TwitterImportPlayer
    ///     {
    ///         PlayerId = 1234,
    ///         FirstName = "Kevin",
    ///         LastName  = "Love",
    ///         TeamId    = 12,
    ///         FullNameOnly = true          // surname is an ordinary word
    ///     });
    ///
    ///     import.Teams.Add(new TwitterImportTeam
    ///     {
    ///         TeamId = 12,
    ///         City = "Portland",
    ///         Name = "Trail Blazers",
    ///         Abbreviation = "POR",
    ///         Aliases = { "Blazers", "Rip City" }
    ///     });
    ///
    ///     string json = import.RenderAsJson();
    /// </summary>
    public class TwitterImport
    {
        /// <summary>1 = basketball, 2 = baseball.</summary>
        public int SportId { get; set; }

        public List<TwitterImportPlayer> Players { get; set; }
            = new List<TwitterImportPlayer>();

        public List<TwitterImportTeam> Teams { get; set; }
            = new List<TwitterImportTeam>();

        private static readonly JsonSerializerSettings Settings =
            new JsonSerializerSettings
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
                NullValueHandling = NullValueHandling.Ignore
            };

        public string RenderAsJson()
            => JsonConvert.SerializeObject(this, Settings);

        public string RenderAsJson(bool indented)
            => JsonConvert.SerializeObject(this,
                indented ? Formatting.Indented : Formatting.None, Settings);
    }

    public class TwitterImportPlayer
    {
        /// <summary>Basketball Monster's player id.</summary>
        public int PlayerId { get; set; }

        public string FirstName { get; set; } = "";
        public string LastName { get; set; } = "";

        /// <summary>Matches TeamId on one of the teams in the same payload.</summary>
        public int? TeamId { get; set; }

        /// <summary>
        /// Set this for surnames that are ordinary words - Love, Green, White,
        /// Young. Those players will only match when the first name appears in
        /// the tweet as well, which avoids "some love for Walsh" reading as a
        /// reference to Kevin Love.
        /// </summary>
        public bool FullNameOnly { get; set; }

        /// <summary>Nicknames and alternate spellings. Matched on their own.</summary>
        public List<string> Aliases { get; set; } = new List<string>();
    }

    public class TwitterImportTeam
    {
        public int TeamId { get; set; }

        public string City { get; set; } = "";
        public string Name { get; set; } = "";
        public string Abbreviation { get; set; } = "";

        /// <summary>
        /// However people actually write it - Blazers, Sixers, Cavs. Worth
        /// filling in: team mentions are what break ties between players who
        /// share a surname.
        /// </summary>
        public List<string> Aliases { get; set; } = new List<string>();
    }
}
