#!/usr/bin/env bash
# Installs the Mullvad split-tunnel bar button for Noctalia (Hyprland).
# Safe to run again: it updates files in place and skips steps already done.
#
#   ./install.sh                 install, add the button next to "network"
#   ./install.sh --after tray    add the button after another widget instead

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="$HOME/.local/bin"
PLUGIN_ROOT="$HOME/.local/share/noctalia-local-plugins"
PLUGIN_ID="ps/mullvad-split"
SOURCE_NAME="local"
WIDGET_NAME="mullvad-split"
FAV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/mullvad-split/favourites"
AFTER=""

while [ $# -gt 0 ]; do
    case $1 in
        --after) AFTER=$2; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

say "Checking requirements"
for cmd in mullvad mullvad-exclude jq hyprctl noctalia python3; do
    command -v "$cmd" >/dev/null || die "'$cmd' is not installed"
done
pgrep -x noctalia >/dev/null || die "Noctalia isn't running; start it and run this again"
mullvad split-tunnel list >/dev/null 2>&1 || die "can't reach the Mullvad daemon (is mullvad-daemon running?)"

say "Installing script to $BIN_DIR/mullvad-split-menu"
install -Dm755 "$HERE/bin/mullvad-split-menu" "$BIN_DIR/mullvad-split-menu"

say "Installing Noctalia plugin to $PLUGIN_ROOT/mullvad-split"
mkdir -p "$PLUGIN_ROOT/mullvad-split"
cp "$HERE"/noctalia-plugin/mullvad-split/* "$PLUGIN_ROOT/mullvad-split/"

if [ ! -f "$FAV_FILE" ]; then
    say "Creating empty favourites list at $FAV_FILE"
    mkdir -p "$(dirname "$FAV_FILE")"
    printf '# Name|process|launch command\n' > "$FAV_FILE"
fi

# Capture first: `cmd | grep -q` under pipefail fails when grep exits early.
SOURCES=$(noctalia msg plugins source list 2>/dev/null || true)
PLUGINS=$(noctalia msg plugins list 2>/dev/null || true)

if grep -qF "$PLUGIN_ROOT" <<<"$SOURCES"; then
    say "Plugin source already registered"
else
    say "Registering plugin source '$SOURCE_NAME'"
    noctalia msg plugins source add "$SOURCE_NAME" path "$PLUGIN_ROOT" >/dev/null
    sleep 1
fi

if grep -qE "^$PLUGIN_ID .* enabled" <<<"$PLUGINS"; then
    # Already on: toggle it so Noctalia picks up updated files.
    say "Reloading plugin"
    noctalia msg plugins disable "$PLUGIN_ID" >/dev/null
    sleep 0.5
fi
say "Enabling plugin $PLUGIN_ID"
noctalia msg plugins enable "$PLUGIN_ID" >/dev/null
sleep 1

say "Adding the button to the bar"
noctalia msg config-set "widget.$WIDGET_NAME.type" "\"$PLUGIN_ID:button\"" >/dev/null

# Work out the new widget list for the first enabled bar: keep everything as
# is and insert the button after $AFTER (default: before "network", else at
# the end). Read the "full" export: the plain one leaves out sections still at
# their built-in defaults, and writing one of those would replace it.
read -r BAR_PATH NEW_LIST < <(noctalia config export full | python3 -c '
import sys, tomllib, json
cfg = tomllib.loads(sys.stdin.read())
widget, after = sys.argv[1], sys.argv[2]
bars = cfg.get("bar", {})
order = bars.get("order") or [k for k, v in bars.items() if isinstance(v, dict)]
names = [n for n in order if isinstance(bars.get(n), dict) and bars[n].get("enabled", True)]
if not names:
    sys.exit("no enabled bar in the Noctalia config")
name = names[0]
bar = bars[name]
section = next((k for k in ("end", "center", "start") if widget in bar.get(k, [])), None) or \
          next((k for k in ("end", "center", "start") if bar.get(k)), "end")
items = list(bar.get(section, []))
if widget not in items:
    if after and after in items:
        items.insert(items.index(after) + 1, widget)
    elif "network" in items:
        items.insert(items.index("network"), widget)
    else:
        items.append(widget)
print(f"bar.{name}.{section}", json.dumps(items))
' "$WIDGET_NAME" "$AFTER")
noctalia msg config-set "$BAR_PATH" "$NEW_LIST" >/dev/null

say "Done. Right click the ⑂ icon in the bar for the quick popup, click it for the manager."
