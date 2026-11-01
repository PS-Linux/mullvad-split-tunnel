#!/usr/bin/env bash
# Removes the Mullvad split-tunnel bar button. Leaves your favourites list
# (~/.config/mullvad-split/favourites) in place.

set -uo pipefail

PLUGIN_ROOT="$HOME/.local/share/noctalia-local-plugins"
PLUGIN_ID="ps/mullvad-split"
WIDGET_NAME="mullvad-split"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

say "Removing the button from the bar"
read -r BAR_PATH NEW_LIST < <(noctalia config export full | python3 -c '
import sys, tomllib, json
cfg = tomllib.loads(sys.stdin.read())
widget = sys.argv[1]
for name, bar in cfg.get("bar", {}).items():
    if not isinstance(bar, dict):
        continue
    for section in ("start", "center", "end"):
        if widget in bar.get(section, []):
            print(f"bar.{name}.{section}", json.dumps([w for w in bar[section] if w != widget]))
            sys.exit()
' "$WIDGET_NAME")
[ -n "${BAR_PATH-}" ] && noctalia msg config-set "$BAR_PATH" "$NEW_LIST" >/dev/null

say "Disabling plugin"
noctalia msg plugins disable "$PLUGIN_ID" >/dev/null 2>&1

say "Removing files"
rm -f "$HOME/.local/bin/mullvad-split-menu"
rm -f "$PLUGIN_ROOT"/mullvad-split/*.luau "$PLUGIN_ROOT"/mullvad-split/plugin.toml
rmdir "$PLUGIN_ROOT/mullvad-split" 2>/dev/null

say "Done. The '[widget.$WIDGET_NAME]' entry and the 'local' plugin source stay in"
say "Noctalia's settings; they're harmless, or remove them in Settings."
