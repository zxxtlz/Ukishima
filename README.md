# 浮島 Ukishima

> A Quickshell desktop shell for Hyprland and niri.

> [!IMPORTANT]
> **This is a personal fork of [amanhex/Ukishima](https://github.com/amanhex/Ukishima)** (fork: [`zxxtlz/Ukishima`](https://github.com/zxxtlz/Ukishima)). It tracks upstream `master` and layers a small set of local changes on top. Everything not listed under [How this fork differs](#how-this-fork-differs) is upstream, unmodified. Upstream is the canonical project — use its docs and issue tracker unless a problem is specific to a change listed below.

Ukishima (浮島, *"floating island"*) puts a pill at the top of every monitor and a dock along the bottom. The pill expands in place into surfaces — launcher, media, settings and the rest — rather than opening separate panels. It is a self-contained Quickshell config and does not edit your compositor files.

## How this fork differs

This fork = upstream Ukishima **plus** the following local changes (and nothing else):

- **Readable dynamic palette.** The wallpaper-derived palette now enforces a minimum contrast for every text tier, so the date, captions and secondary copy stay legible on any wallpaper. The contrast solver tries both lightening and darkening (the original assumed dark text and could make mid-tone light surfaces *worse*), and the generated palette records which tone (`light`/`dark`) it settled on. Implemented in `scripts/wallcolors.py` and mirrored in `Singletons/PaletteHue.qml`.
- **Dynamic dock tone.** The dock's dynamic and manual modes tint from the generated palette, and its decorative tokens (border, sheen, hover, running dot) plus the static-copy fallbacks choose light or dark from the palette tone — so a dynamic dock stays readable on a light wallpaper instead of keeping white-on-light borders.
- **Dock icon fix.** A window's class is resolved through its desktop entry's `StartupWMClass` (new `byStartupClass()` in `lib/apps.js`, unit-tested) before the coarse app-key fallback, with a generic app-window glyph when nothing matches. This fixes apps such as **LocalSend** that previously showed a blank dock slot.
- **Compressor progress face.** A new `Singletons/Compress.qml` tracks a running `compress10mb` job; the resting pill shows a determinate progress bar, the current file and a percentage. Toggle under **Settings → Modules**.
- **Package updater hover action.** A download glyph in the pill's hover row runs `~/.local/bin/update-all` in a terminal (pacman/AUR + Flatpak + shell plugins + cache cleanup) instead of opening a surface. Toggle under **Settings → Modules**.
- **Labelled mixer pickers.** The mixer header's input and output pickers show the current device name and a chevron rather than an icon alone.
- **nvibrant fix.** Vibrance is written to the actual connected GPU ports (probed once) instead of assuming ports 0–2, so multi-monitor and non-default port layouts get the correct value.

To update this fork, merge the upstream `master` branch into yours (this repo keeps `origin` pointed at upstream `amanhex/Ukishima` and pushes to the `fork` remote).

## Preview

<p align="center">
<a href="https://ukishima.uklab.workers.dev/">
  <img src="assets/ukishima-readme-banner.png" width="100%" alt="Ukishima">
</a>
</p>

Explore the animated showcase, features and settings on the [Ukishima website](https://ukishima.uklab.workers.dev/).

## Features

- **Pill** — one per monitor. Hovering expands it into a row of modules; surfaces open from the pill and fold back into it when dismissed. Right-clicking the pill cycles through the media surface, the timer, and up to two more surfaces chosen under **Settings → Interface → Right-click**.
- **Dock** — pinned and running apps, hover magnification, window previews, auto-hide, and its own theme.
- **Surfaces** — launcher, emoji, weather, calendar, media player, mixer, wallpaper browser and Wallhaven search, screen recorder, clipboard, Wi-Fi, Bluetooth, battery, power menu, system monitor, scratchpad and settings.
- **Surface styles** — the pill, media player, mixer, system monitor, scratchpad and lock screen each offer several layouts, under **Settings → Appearance → Surface Styles**.
- **Wallpapers** — shuffled image wallpapers through `awww`, video wallpapers through `mpvpaper`, a cover/contain/stretch/center fit, and a palette taken from the current wallpaper.
- **Compositor-aware** — workspaces, window state, keyboard layout, lock backends and dependency checks follow Hyprland or niri. Hyprland-only features are hidden on niri.
- **Extras** — night light (Hyprland), game mode, keep-awake and an in-app updater.

## Requirements

- Linux with Wayland, running **Hyprland** or **niri**
- **Quickshell** 0.3.0 or newer
- The command-line tools listed in [Dependencies](docs/DEPENDENCIES.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

The installer clones into `~/.local/share/quickshell/ukishima`, checks the tools your compositor needs, and prints the startup line for your compositor config. If that directory already contains a clean official `master` checkout, it offers to update it; anything else is left untouched.

## Launch

**Hyprland** (`~/.config/hypr/hyprland.conf`):

```ini
exec-once = ~/.local/share/quickshell/ukishima/launch.sh
```

**Hyprland — Lua**:

```lua
hl.exec_cmd("~/.local/share/quickshell/ukishima/launch.sh")
```

**niri** (`~/.config/niri/config.kdl`):

```kdl
spawn-at-startup "sh" "-c" "exec $HOME/.local/share/quickshell/ukishima/launch.sh"
```

Start `awww-daemon` alongside the shell so wallpapers apply immediately:

```ini
# Hyprland
exec-once = awww-daemon
```

```kdl
# niri
spawn-at-startup "awww-daemon"
```

## Keybinds

Ukishima does not install keybindings. Call its IPC from your own, for example:

```bash
qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
```

See the [Keybindings & IPC Guide](docs/KEYBINDINGS.md) for Hyprland, Hyprland Lua and niri examples, plus the full IPC list.

## Lock

Ukishima provides its own lockscreen and can also hand off to an external locker:

- **Hyprland** — Hyprlock or Quickshell
- **niri** — swaylock or Quickshell

Choose a backend under **Settings → Lock screen**, then bind `~/.local/share/quickshell/ukishima/scripts/lock.sh` to a shortcut.

## Update

Open **Settings → Update** and choose **Check for Updates**. The updater only works on a clean official `master` checkout: uncommitted changes block it, and any other checkout is refused. When updates are available it fast-forwards and reloads the shell.

You can also run the install command again. It asks before updating and, like the in-app updater, only touches a clean `master` checkout that tracks `origin/master`; local changes and development checkouts are left alone.

## Troubleshooting

Quickshell output is written to `$XDG_STATE_HOME/ukishima/ukishima.log` (default `~/.local/state/ukishima/ukishima.log`), with one rotated copy, and is also printed to the terminal when you launch from one. The log can contain file paths, so check it before posting it publicly. To see which tools are missing, run:

```bash
~/.local/share/quickshell/ukishima/scripts/check-deps.sh
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
```

The script asks for confirmation, stops a running shell, and removes the application directory, settings, state, caches and generated wallpaper stills. It refuses to remove a modified or non-`master` git checkout. Your own wallpapers, other applications and compositor configuration are not touched. Remove the startup line and any keybindings afterwards.

## Credits

Built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei) — the pill concept, the morphing-surface architecture and most of the original codebase. All credit for the base code goes to the original author.

The media, mixer, system monitor, scratchpad and lock screen surface styles are inspired by [**Chaldea**](https://github.com/Aleph1-9012/Chaldea) by [**Aleph1-9012**](https://github.com/Aleph1-9012).
