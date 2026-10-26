#!/usr/bin/env bash
# Keyboard-shortcut cheat sheet: wofi + hyprctl. Opened by SUPER+/ and by
# Settings -> Keyboard -> Keyboard shortcuts. Same wofi styling as the other
# menus, so it inherits the Catppuccin theme automatically.
#
# Built live from `hyprctl binds -j`, so it always matches what's actually
# bound, including binds added later. The text is each bind's description
# (bindd = MODS, KEY, Description, ...); a bind without one shows its raw
# command instead. Type to search keys and descriptions alike; picking a line
# just closes the list.

set -uo pipefail

# Key names as they read on the keyboard; anything not listed shows as-is,
# minus the XF86 prefix the special keys carry.
list=$(hyprctl binds -j | jq -r '
	{ "Return": "Enter", "slash": "/", "bracketleft": "[", "bracketright": "]",
	  "left": "←", "right": "→", "up": "↑", "down": "↓", "Print": "Print Screen",
	  "mouse_down": "Scroll down", "mouse_up": "Scroll up",
	  "mouse:272": "Left-drag", "mouse:273": "Right-drag",
	  "XF86AudioRaiseVolume": "Volume Up key", "XF86AudioLowerVolume": "Volume Down key",
	  "XF86AudioMute": "Mute key", "XF86AudioMicMute": "Mic Mute key",
	  "XF86AudioPlay": "Play key", "XF86AudioNext": "Next key", "XF86AudioPrev": "Previous key",
	  "XF86MonBrightnessUp": "Brightness Up key", "XF86MonBrightnessDown": "Brightness Down key"
	} as $names
	# modmask bits: SHIFT 1, CTRL 4, ALT 8, SUPER 64. Shown in that fixed order.
	| def bit($b): (.modmask / $b | floor) % 2 == 1;
	.[]
	| ([ (if bit(64) then "SUPER" else empty end), (if bit(4) then "CTRL" else empty end),
	     (if bit(8) then "ALT" else empty end), (if bit(1) then "SHIFT" else empty end),
	     ($names[.key] // (.key | sub("^XF86"; ""))) ] | join(" + ")) as $combo
	| (if .has_description then .description
	   else ("\(.dispatcher) \(.arg)" | if length > 40 then .[:39] + "…" else . end) end) as $what
	| $combo + (" " * ([24 - ($combo | length), 1] | max)) + $what
')

[ -n "$list" ] || exit 0

# allow_markup=false: a description with & or < would otherwise misrender.
printf '%s\n' "$list" | wofi --dmenu --insensitive --no-custom-entry \
	--cache-file /dev/null --define allow_markup=false \
	--width 600 --lines 16 --prompt "Keyboard shortcuts (type to search)" >/dev/null
exit 0
