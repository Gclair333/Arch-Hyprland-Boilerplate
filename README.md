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
```

## Dependencies

```bash
sudo pacman -S hyprland waybar wofi kitty awww ttf-jetbrains-mono-nerd
```

The Waybar volume module shells out to `wpctl`, so it also expects PipeWire:

```bash
sudo pacman -S pipewire pipewire-pulse wireplumber
```

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
cp -r hypr waybar wofi ~/.config/
```

Then drop a wallpaper at `~/Pictures/wallpaper.jpg`, or edit the path in `hypr/hyprland.conf`.

## Keybindings

| Combo | Action |
| --- | --- |
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + R` / `SUPER + D` | App launcher (wofi) |
| `SUPER + Q` | Close focused window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + V` | Toggle floating |
| `SUPER + 1`…`5` | Switch to workspace |
| `SUPER + SHIFT + 1`…`5` | Send focused window to workspace |
| `SUPER + scroll` | Cycle workspaces |

Workspaces stop at 5 to match `persistent-workspaces` in `waybar/config` — extend both together
if you want more. You can also just click the pills in the bar.

Still deliberately sparse: there are **no** binds for moving focus between tiled windows, media
keys, or exiting Hyprland. Add your own in the `bind =` block at the bottom of
`hypr/hyprland.conf`.

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
layerrule = blur on, ignore_alpha 0.3, match:namespace waybar
```

The pre-0.53 form (`layerrule = blur, waybar`) is rejected outright — `blur` now takes an explicit
`on`/`off`, `ignorealpha` became `ignore_alpha`, and targets are matched with `match:`. Most guides
and dotfile repos online still show the old syntax. If a rule seems to do nothing, check
`hyprctl configerrors`.
