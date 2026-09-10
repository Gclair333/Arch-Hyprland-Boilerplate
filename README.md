# Arch Hyprland Boilerplate

A deliberately minimal [Hyprland](https://hyprland.org/) setup for Arch Linux, themed with
[Catppuccin Mocha](https://catppuccin.com/palette). Small enough to read top to bottom in a
few minutes, then build on — not a full rice.

## What's here

- **Hyprland** — rounded corners, blur, shadows, and two custom animation curves
- **Waybar** — the bar itself is invisible; each module is its own floating frosted pill
- **wofi** — centered translucent launcher with fuzzy matching and app icons
- One palette, defined once per stylesheet as `@define-color` — swap the accent in a single place

```
hypr/hyprland.conf     compositor: monitors, decoration, animations, binds
waybar/config          bar layout and modules
waybar/style.css       bar theming (palette lives at the top)
wofi/config            launcher behavior and geometry
wofi/style.css         launcher theming
scripts/screenshot.sh  grim/slurp wrapper (region/screen, copy/save)
scripts/wifi-menu.sh   wofi + nmcli Wi-Fi picker, opened by the network pill
```

## Dependencies

```bash
sudo pacman -S hyprland waybar wofi kitty awww ttf-jetbrains-mono-nerd grim slurp wl-clipboard
```

`grim` + `slurp` + `wl-clipboard` back the screenshot binds and `scripts/screenshot.sh` —
core here because a screenshot key is table stakes for a usable desktop.

The Waybar volume module and the volume keys use `wpctl`, so it also expects PipeWire:

```bash
sudo pacman -S pipewire pipewire-pulse wireplumber
```

### Optional

Everything below is optional — the setup works without it, but these binds and click actions stay
inert until the matching tool is present.

```bash
sudo pacman -S networkmanager            # Wi-Fi picker on the network pill (nmcli)
sudo pacman -S playerctl                 # play/pause/next/prev media keys
sudo pacman -S brightnessctl             # brightness keys (the bar slider needs nothing)
```

`networkmanager` must also be enabled: `sudo systemctl enable --now NetworkManager`.

### A note on `awww` (formerly `swww`)

Upstream renamed the wallpaper daemon `swww` → `awww` in October 2025 and moved from GitHub to
[Codeberg](https://codeberg.org/LGFae/awww). Same project, same author, continuing version line.

On Arch, `pacman -S swww` still resolves — the `awww` package declares `Provides: swww` and
`Replaces: swww` — but **the binaries are `awww` and `awww-daemon`**, not `swww`/`swww-daemon`.
Configs and scripts written against the old names fail silently. This repo uses the new names.

## Install

These files map directly onto `~/.config`. Back up anything you already have:

```bash
cp -r ~/.config/hypr ~/.config/hypr.bak     # repeat for waybar, wofi
cp -r hypr waybar wofi scripts ~/.config/
chmod +x ~/.config/scripts/*.sh
```

Then drop a wallpaper at `~/Pictures/wallpaper.jpg`, or edit the path in `hypr/hyprland.conf`
(line 5). That path is hardcoded — if no file is there, Hyprland starts fine but the background
stays black.

## Keybindings

| Combo | Action |
| --- | --- |
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + D` | App launcher (wofi) |
| `SUPER + Q` | Close focused window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + V` | Toggle floating |
| `SUPER + SHIFT + E` | Exit Hyprland |

**Workspaces**

| Combo | Action |
| --- | --- |
| `SUPER + 1`…`5` | Switch to workspace |
| `SUPER + SHIFT + 1`…`5` | Send focused window to workspace |
| `SUPER + scroll` | Cycle workspaces |

Capped at 5 to match `persistent-workspaces` in `waybar/config` — extend both together if you
want more. You can also click the pills in the bar.

**Windows**

| Combo | Action |
| --- | --- |
| `SUPER + ←↑↓→` or `H/J/K/L` | Move focus |
| `SUPER + SHIFT + ←↑↓→` | Move window within the layout |
| `SUPER + CTRL + ←↑↓→` | Resize window |
| `SUPER + drag` / `SUPER + right-drag` | Move / resize with the mouse |

**Media and screenshots** — these need the optional packages above.

| Combo | Action |
| --- | --- |
| `Print` | Whole screen to clipboard |
| `SUPER + S` | Select a region to clipboard |
| `SUPER + SHIFT + S` | Select a region to clipboard **and** `~/Pictures/Screenshots/` |
| Volume / mute / mic keys | via `wpctl` |
| Play / next / previous | via `playerctl` |
| Brightness keys | via `brightnessctl` |

## The bar is interactive

| Module | Hover | Click |
| --- | --- | --- |
| Workspaces | — | Switch to it |
| Clock | Month calendar | Toggle time ⇄ date |
| CPU | Usage + load average | — |
| RAM | Used / total / available | — |
| Brightness | Level | **Slides out a drag bar** (scroll also works) |
| Volume | Device + level | **Slides out a drag bar**; scroll adjusts, revealed button mutes |
| Network | SSID, signal, IP | **Wi-Fi picker** (`scripts/wifi-menu.sh` — wofi + nmcli) |
| Battery | Charge + time remaining | — |

Brightness and volume use Waybar's native `backlight/slider` and `pulseaudio/slider` inside a
click-to-reveal `group` drawer. Both write through system APIs Waybar is already linked against
(logind for brightness, PipeWire for volume) — **no `brightnessctl`, `wpctl`, or `video` group
needed** for the bar. Those tools are still listed as optional because the *keybindings* use them.

The brightness slider floors at 5% so a full drag left can't black out the screen. The clock is
12-hour (`%I:%M %p`) — change it to `{:%H:%M}` in `waybar/config` for 24-hour.

## Scripts

Two helpers in `scripts/`, called by the binds and the network pill. Both degrade quietly if
their tools aren't installed.

**`screenshot.sh`** — `grim` + `slurp`, with `wl-copy` to the clipboard and an optional file
copy. `notify-send` is best-effort, so no notification daemon just means no popup.

**`wifi-menu.sh`** — a `wofi` list of nearby networks via `nmcli`: signal glyph, lock marker, a
check on the active one. Picking a saved network reconnects; a new secured one prompts for a
password in a `wofi --password` box. Also has rescan and a Wi-Fi on/off toggle. It reuses
`wofi/style.css`, so it's themed with no extra config. Needs `networkmanager` running; for
editing static/VPN/enterprise connections, `nm-connection-editor` is the GUI.

## Customizing the theme

Every color is a named token at the top of `waybar/style.css` and `wofi/style.css`:

```css
@define-color base  #1e1e2e;
@define-color mauve #cba6f7;   /* the accent */
```

The accent (`@mauve`) drives the active workspace pill and the launcher border. Swap it for
`@blue`, `@green`, or `@peach` and both follow. Catppuccin ships four flavors — replacing the
whole block with Latte, Frappé, or Macchiato values reflavors the setup wholesale.

## Reloading after a change

```bash
killall -SIGUSR2 waybar   # reloads Waybar config + CSS in place
hyprctl reload            # reloads Hyprland
                          # wofi re-reads its config on every launch
```

## Version notes

Written and verified against:

| | |
| --- | --- |
| Hyprland | 0.56.2 |
| Waybar | 0.15.0 |
| wofi | 1.5.3 |
| awww | 0.12.1 |

**Hyprland 0.53 overhauled window and layer rule syntax.** The layer rules here use the current
form:

```bash
layerrule  = blur on, ignore_alpha 0.3, match:namespace waybar
windowrule = float on, size 60% 60%, center on, match:class <some-class>
```

The pre-0.53 forms (`layerrule = blur, waybar` and `windowrule = float, class:foo`) are rejected
outright. Three things changed:

- boolean rules take an explicit value — `blur on`, `float on`, not bare `blur`/`float`
- `ignorealpha` became `ignore_alpha`
- targets are matched with `match:` — `match:namespace`, `match:class`

Most guides and dotfile repos still show the old syntax, and a rejected rule doesn't announce
itself. If a rule seems to do nothing, run `hyprctl configerrors`.
