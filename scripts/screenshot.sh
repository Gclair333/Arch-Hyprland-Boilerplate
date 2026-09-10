#!/usr/bin/env bash
# grim/slurp screenshot helper.
#
#   screenshot.sh region        select a region -> clipboard
#   screenshot.sh region-save   select a region -> clipboard + file
#   screenshot.sh screen        whole output   -> clipboard
#   screenshot.sh screen-save   whole output   -> clipboard + file
#
# Files land in $XDG_SCREENSHOTS_DIR, else ~/Pictures/Screenshots.
# notify-send calls are best-effort: no notification daemon, no error.

set -euo pipefail

mode="${1:-region}"
dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
file="$dir/$(date +%Y%m%d-%H%M%S).png"

notify() { command -v notify-send >/dev/null && notify-send -a screenshot "$@" || true; }

case "$mode" in
	region | region-save)
		geom=$(slurp) || exit 0   # Esc / right-click cancels slurp
		;;
esac

case "$mode" in
	region)
		grim -g "$geom" - | wl-copy
		notify "Screenshot copied" "Region on the clipboard"
		;;
	region-save)
		mkdir -p "$dir"
		grim -g "$geom" "$file"
		wl-copy < "$file"
		notify -i "$file" "Screenshot saved" "${file/#$HOME/~}"
		;;
	screen)
		grim - | wl-copy
		notify "Screenshot copied" "Full screen on the clipboard"
		;;
	screen-save)
		mkdir -p "$dir"
		grim "$file"
		wl-copy < "$file"
		notify -i "$file" "Screenshot saved" "${file/#$HOME/~}"
		;;
	*)
		echo "usage: screenshot.sh [region|region-save|screen|screen-save]" >&2
		exit 1
		;;
esac
