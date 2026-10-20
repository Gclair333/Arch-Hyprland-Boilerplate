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
| `~/.config/scripts/power-menu.sh` | The session menu behind the power pill. A small example of a `wofi --dmenu` menu with a confirm step. |
| `~/.config/scripts/settings-menu.sh` | The Settings menu behind the gear pill and `SUPER + I`. The biggest script here: worth reading for how a setting is applied live (`hyprctl keyword`) and also saved to a file Hyprland reads at every start. |
| `~/.config/hypr/settings.conf`, `settings-idle.conf` | Your own choices, written by the Settings menu (they appear on your first change). One `option = value` line each, so they double as examples of Hyprland's `category:option` syntax. Delete a line to undo it. |
| `~/.config/hypr/hyprlock.conf` | The lock screen's look: background, clock, password field, and the warning line under it. |
| `~/.config/hypr/hypridle.conf` | What happens when you stop touching the machine, and after how long: dim, lock, screen off, sleep. The default timings are at the top; the Settings menu overrides them. |
| `~/.config/scripts/backlight`, `lock-hint` | Small helpers: screen brightness through logind (no root needed), and the lock screen's warning line. |
| `~/.config/scripts/wallpaper-*`, `mpvpaper-ipc` | The optional video wallpaper. `wallpaper-start` launches it, `mpvpaper-ipc` talks to it while it runs, and the rest build on that. The comments explain *why* each mpv option is there — several were found the hard way. |
| `~/.config/scripts/watch-anime*`, `*-feed` | The optional anime-on-the-wallpaper layer. `mpvpaper-feed` is the interesting one: a fake "player" that hands the stream to the wallpaper instead of opening a window. |

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
man mpvpaper                  the video wallpaper's flags
man mpv                       everything mpvpaper's -o accepts; see "JSON IPC"
                               for what the wallpaper scripts send it
```

If `man` itself is missing, that's normal — Arch's base install doesn't include it:
`sudo pacman -S man-db`. The pages are already there; only the reader isn't.

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
- `~/.config/scripts/mpvpaper-ipc get time-pos` — ask the running video wallpaper what it's
  doing. Any mpv property works (`pause`, `path`, `hwdec-current`); run it twice a few seconds
  apart and the number should move.
- `faillock --user $USER` — how many wrong passwords are counting against you right now (see
  the third trap below). `--reset` on the end clears them.

## Use git as a build log

If you generated your own repo from this template, its commit history carries forward. Reading
commits oldest-to-newest (`git log -p` in the repo) is closer to a guided tour than a changelog —
each one explains *why* a line exists, not just what changed. Do the same in your own repo as you
customize: a commit message that says why beats one that just restates the diff.

## Three traps everyone hits early

- **The `swww` → `awww` rename.** Upstream renamed the wallpaper daemon and moved to Codeberg;
  `pacman -S swww` still resolves via `Provides`/`Replaces`, but the binaries are `awww` /
  `awww-daemon`. See the README for details.
- **Hyprland 0.53's rule syntax overhaul.** `layerrule`/`windowrule` boolean fields now need an
  explicit value (`blur on`, not bare `blur`), and targets are matched with `match:`. Most
  tutorials online still show the old form, and a rejected rule fails silently — `hyprctl
  configerrors` is how you catch it. See the README's Version notes section for the full story.
- **Three wrong passwords lock you out for 10 minutes.** Arch's `pam_faillock` then refuses even
  the right password, at the lock screen, the login screen, and `sudo` alike, which feels exactly
  like "my password stopped working". Wait 10 minutes or restart. The lock screen here warns you
  before the last try and shows when it will let you back in. See the README's lock screen section.
