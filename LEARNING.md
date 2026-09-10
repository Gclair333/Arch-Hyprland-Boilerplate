# Learning your way around

This boilerplate is meant to be read, not just installed. If you're new to Arch, Hyprland,
or ricing in general, here's a map of what lives where and how to actually poke at it.

## The files, and what each one governs

| Path | What it controls |
| --- | --- |
| `~/.config/hypr/hyprland.conf` | The compositor: monitors, autostart, input, gaps/borders, decoration (rounding/blur/shadow), animations, and every keybind. This is the one file that touches everything else — Waybar and wofi are just programs it launches. |
| `~/.config/waybar/config` | The bar's **content** — which modules exist, what order, what each does on click/scroll. JSON with `//` comments allowed (jsonc). |
| `~/.config/waybar/style.css` | The bar's **look**. Plain GTK CSS. The palette is defined once at the top as `@define-color` and used everywhere else — start there to reskin it. |
| `~/.config/wofi/config` | Launcher behavior: size, position, matching mode, terminal to use. |
| `~/.config/wofi/style.css` | Launcher look — same `@define-color` pattern as Waybar's. |
| `~/.config/scripts/screenshot.sh` | Wraps `grim` + `slurp` + `wl-copy` so the keybinds don't carry a long inline command. Run it directly in a terminal to see what each mode does. |
| `~/.config/scripts/wifi-menu.sh` | The Wi-Fi picker behind the network pill: `nmcli` for data, `wofi` for the menu. The gnarliest part is the text parsing (`nmcli`'s terse output escapes `:` inside SSIDs) — worth reading slowly if you want to understand shell field-splitting. |

None of these need a GUI editor to open. `wofi`'s launcher (`SUPER + D`) only lists installed
*applications* — it can't open a file by name. From a terminal: `nano <path>` to edit,
`less <path>` to page through, `cat <path>` to dump it straight out.

## Read the actual docs, not just this file

Everything above was built by reading these — all installed locally, no internet required:

```
man Hyprland                  the compositor binary itself
man hyprctl                   the CLI for querying/controlling it
man waybar                    overview + the "group"/"drawer" syntax
man waybar-styles             what CSS selectors exist and mean
man waybar-<module>           one page per module, e.g. waybar-pulseaudio,
                               waybar-backlight-slider, waybar-hyprland-workspaces
man 1 wofi                    command-line flags
man 5 wofi                    config file options
man 7 wofi                    style.css selectors
```

Hyprland's config *options* (as opposed to the `hyprctl` command) aren't in a man page — the
[wiki](https://wiki.hyprland.org) is the source of truth there.

## Commands worth running yourself

- `hyprctl reload` after editing `hyprland.conf` — instant, no logout needed.
- `hyprctl configerrors` right after — catches a bad line that would otherwise fail silently.
- `killall -SIGUSR2 waybar` after editing either Waybar file — reloads both in place.
- `hyprctl binds` — every keybind active right now, straight from the compositor. The ground
  truth if the config and what actually happens disagree.
- `hyprctl monitors` / `hyprctl clients` — inspect live state generally; the fastest way to
  answer "why isn't this doing what I expect."

## Use git as a build log

If you generated your own repo from this template, its commit history carries forward. Reading
commits oldest-to-newest (`git log -p` in the repo) is closer to a guided tour than a changelog —
each one explains *why* a line exists, not just what changed. Do the same in your own repo as you
customize: a commit message that says why beats one that just restates the diff.

## Two traps everyone hits early

- **The `swww` → `awww` rename.** Upstream renamed the wallpaper daemon and moved to Codeberg;
  `pacman -S swww` still resolves via `Provides`/`Replaces`, but the binaries are `awww` /
  `awww-daemon`. See the README for details.
- **Hyprland 0.53's rule syntax overhaul.** `layerrule`/`windowrule` boolean fields now need an
  explicit value (`blur on`, not bare `blur`), and targets are matched with `match:`. Most
  tutorials online still show the old form, and a rejected rule fails silently — `hyprctl
  configerrors` is how you catch it. See the README's Version notes section for the full story.
