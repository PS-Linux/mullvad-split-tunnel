# Mullvad split-tunnel bar button

A button for the [Noctalia](https://noctalia.dev) bar (Hyprland) that switches
favourite apps in and out of the Mullvad VPN tunnel.

- **Hover** the ⑂ icon: a small popup above it lists your favourites with an
  on/off switch each. Click a row to flip it, or the button at the bottom to
  open the manager.
- **Click** the icon: the manager window opens, where you can add open apps as
  favourites, remove favourites, or stop excluding everything.
- The icon turns the accent colour while any app is bypassing the VPN.

## Install

```bash
./install.sh
```

Re-running it is safe and also updates an existing install. By default the
button goes just before the network icon; use `./install.sh --after tray` to put
it after another widget.

Requirements: Mullvad VPN (app/daemon), Noctalia 5.4+ running on Hyprland, `jq`
and `python3`.

To remove it: `./uninstall.sh` (keeps your favourites list).

## What gets installed where

| File | Purpose |
| --- | --- |
| `~/.local/bin/mullvad-split-menu` | Does the work. Run it without arguments for a launcher-style menu; the plugin uses its `status`, `toggle`, `windows`, `add`, `remove` and `clear` commands. |
| `~/.local/share/noctalia-local-plugins/mullvad-split/` | The Noctalia plugin (`ps/mullvad-split`), registered as plugin source `local`. |
| `~/.config/mullvad-split/favourites` | Your favourites, one per line: `Name\|process\|launch command`. |

The installer also adds a `[widget.mullvad-split]` entry to Noctalia's settings
(`~/.local/state/noctalia/settings.toml`) and puts it in the bar's widget list.

## How it behaves

- Mullvad on Linux excludes **processes**, not apps. Switching a running app
  moves its current processes (and their children) out of the tunnel; open
  connections move once the app reconnects. Starting an app from the popup while
  it's closed (`Not running · starts outside VPN`) is the most reliable way.
- Exclusions end when the app closes or the laptop restarts.
- A process name in the favourites file can be prefixed with `~` to match the
  full command line instead (`pgrep -f`), e.g. for Electron apps that all run as
  `electron`.
- Status is read from the `mullvad-exclusions` cgroup, because
  `mullvad split-tunnel list` misses apps started with `mullvad-exclude`.

## Notes on the Noctalia plugin

- Plugin API reference: `noctalia.d.luau` in the official plugins repo
  (`~/.local/state/noctalia/plugins/sources/official/repo`, read it with
  `git -C <repo> show HEAD:noctalia.d.luau`).
- Attached panels can only align to an end of the bar, not to a widget, so the
  popup is `position = "bottom_right"` and 380px wide to sit over the icon. If
  the icon ends up outside it (more tray icons, different screen), change
  `width` or `position` in `plugin.toml`.
- Noctalia hot-reloads the `.luau` files on save. After changing `plugin.toml`,
  run `noctalia msg plugins disable ps/mullvad-split` and `... enable ...`.
- Check a change with `noctalia plugins lint noctalia-plugin/mullvad-split`.
- Script-driven pointer moves (`hyprctl dispatch movecursor`) don't trigger bar
  hover events, so hover has to be tested by hand. Noctalia's log is
  `~/.cache/noctalia/noctalia.log`; `noctalia.log()` from Lua shows up there as
  `[script-runtime]`.
