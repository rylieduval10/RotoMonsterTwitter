#!/usr/bin/env bash
#
# RotoMonsterUI - "Auto Fill" button on the TweetCard (Ken's 7-29 doc, item 4).
#
# Ken's spec: a button on the tweet that the service reports as pressed, so his
# page can call the Twitter client's AnalyzeWithAIAsync and drop the AI summary
# into the news details box.
#
# Three touches, matching the existing Post/Cancel pattern exactly:
#   1. the button, in the post form's button list
#   2. AutoFillPressed on TweetCardResult
#   3. tweetautofill_ registered as an action prefix + the flag set in Process
#
# Run from the RotoMonsterUI solution root.
#
set -euo pipefail

if [ ! -d Components ] || [ ! -f Components/TweetCard.cs ]; then
  echo "ERROR: run this from the RotoMonsterUI root (Components/TweetCard.cs not found)" >&2
  exit 1
fi

echo "1/3  Adding the button to the post form..."

python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("Components/TweetCard.cs")
t = p.read_text()

if 'tweetautofill' in t:
    print("     TweetCard.cs already has the Auto Fill button")
else:
    old = '''                    new NewsEditFormButton { Text = "Post", Style = ButtonStyle.Primary, Name = Key("tweetpost") },
                    new NewsEditFormButton { Text = "Cancel", Style = ButtonStyle.Secondary, Name = Key("tweetcancel") }'''
    new = '''                    new NewsEditFormButton { Text = "Post", Style = ButtonStyle.Primary, Name = Key("tweetpost") },
                    new NewsEditFormButton { Text = "Auto Fill", Style = ButtonStyle.Info, Name = Key("tweetautofill") },
                    new NewsEditFormButton { Text = "Cancel", Style = ButtonStyle.Secondary, Name = Key("tweetcancel") }'''
    assert old in t, "could not find the Post/Cancel button list"
    t = t.replace(old, new)
    p.write_text(t)
    print("     patched TweetCard.cs")
PYEOF

echo "2/3  Adding AutoFillPressed to the result..."

python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("Services/TweetCardResult.cs")
if not p.exists():
    # some layouts keep the result under Models or alongside the component
    import glob
    hits = glob.glob("**/TweetCardResult.cs", recursive=True)
    assert hits, "TweetCardResult.cs not found"
    p = pathlib.Path(hits[0])

t = p.read_text()
if "AutoFillPressed" in t:
    print("     TweetCardResult already has AutoFillPressed")
else:
    anchor = "        public bool SetTagPressed { get; set; }"
    add = anchor + "\n\n        public bool AutoFillPressed { get; set; }"
    assert anchor in t, "could not find SetTagPressed anchor"
    t = t.replace(anchor, add)
    p.write_text(t)
    print(f"     patched {p}")
PYEOF

echo "3/3  Detecting the press in the service..."

python3 - <<'PYEOF'
import pathlib
p = pathlib.Path("Services/TweetCardService.cs")
t = p.read_text()

changed = False

# a) register the action prefix so GetActiveTweetId resolves the card from the
#    Auto Fill button alone (it's an action, present only when clicked).
if '"tweetautofill_"' not in t:
    old = '''        private static readonly string[] ActionPrefixes =
        {
            "tweetpost_", "tweetsettag_", "tweetcancel_"
        };'''
    new = '''        private static readonly string[] ActionPrefixes =
        {
            "tweetpost_", "tweetsettag_", "tweetcancel_", "tweetautofill_"
        };'''
    assert old in t, "could not find ActionPrefixes"
    t = t.replace(old, new)
    changed = True

# b) set the flag in Process, next to the other button checks.
if "AutoFillPressed" not in t:
    anchor = '''            var cancelKey = "tweetcancel_" + tweetId;
            if (params_.ContainsKey(cancelKey) || eventTarget == cancelKey)
                result.CancelPressed = true;'''
    add = anchor + '''

            var autoFillKey = "tweetautofill_" + tweetId;
            if (params_.ContainsKey(autoFillKey) || eventTarget == autoFillKey)
                result.AutoFillPressed = true;'''
    assert anchor in t, "could not find the cancel-key block"
    t = t.replace(anchor, add)
    changed = True

if changed:
    p.write_text(t)
    print("     patched TweetCardService.cs")
else:
    print("     TweetCardService already handles Auto Fill")
PYEOF

echo ""
echo "Brace check (no SDK here to build)..."
python3 - <<'PYEOF'
for f in ["Components/TweetCard.cs", "Services/TweetCardService.cs"]:
    s = open(f).read()
    assert s.count("{") == s.count("}"), f"{f}: brace mismatch"
    print(f"  {f}: braces balanced")
PYEOF

cat <<'MSGEOF'

==================================================================
Done. The TweetCard now shows Post / Auto Fill / Cancel.

When Auto Fill is pressed, TweetCardResult.AutoFillPressed comes
back true. On Ken's page that's his cue to:

  var result = await client.AnalyzeWithAIAsync(tweetText);
  // drop result.Summary into the news details box, re-render

Nothing here calls the AI - the component just reports the press,
exactly as Ken's doc describes. Build it in your solution to
confirm (no SDK in this environment).
==================================================================
MSGEOF
