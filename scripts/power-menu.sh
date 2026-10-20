#!/usr/bin/env bash
# Theme-consistent session/power menu: wofi + logind.
# Bound to the Waybar power pill (on-click). Same wofi styling as the app
# launcher and Wi-Fi picker, so it inherits the Catppuccin theme automatically.

set -uo pipefail

wofi_menu() {
	wofi --dmenu --insensitive --cache-file /dev/null \
	     --width 280 --height 300 --prompt "${1:-Session}"
}

# Destructive actions get a second look. Lock / suspend / switch-user don't —
# they're all trivially recoverable.
confirm() {
	local answer
	answer=$(printf '󰄬  Yes, %s\n󰅖  Cancel' "$1" | wofi_menu "Are you sure?")
	[[ "$answer" == *"Yes,"* ]]
}

sel=$(printf '%s\n' \
	"󰌾  Lock" \
	"󰀄  Switch User" \
	"󰍃  Log Out" \
	"󰒲  Suspend" \
	"󰜉  Reboot" \
	"󰐥  Power Off" \
	| wofi_menu "Session")

[ -z "$sel" ] && exit 0

case "$sel" in
	*"Lock")
		# Via logind, not `hyprlock` directly: logind then emits the Lock
		# signal that wallpaper-lock-watch listens for, so the video wallpaper
		# pauses instead of decoding away behind the lock screen.
		loginctl lock-session
		;;

	*"Switch User")
		# GDM's proper switch-user path — spawns a greeter on a fresh VT and
		# leaves this session running in the background.
		# Lock this session first: without it, your desktop sits unlocked on
		# tty2 while someone else logs in on the new one.
		loginctl lock-session
		sleep 0.5
		dbus-send --system --print-reply=literal \
			--dest=org.gnome.DisplayManager \
			/org/gnome/DisplayManager/LocalDisplayFactory \
			org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay \
			>/dev/null 2>&1 \
			|| notify-send "Switch User failed" "GDM did not create a new session." 2>/dev/null
		;;

	*"Log Out")
		# Matches the existing SUPER SHIFT+E bind rather than introducing a
		# second way to end the session.
		confirm "log out" && hyprctl dispatch exit
		;;

	*"Suspend")
		# logind emits PrepareForSleep, so the wallpaper pauses on the way down
		# and resumes on wake (see wallpaper-lock-watch).
		systemctl suspend
		;;

	*"Reboot")
		confirm "reboot" && systemctl reboot
		;;

	*"Power Off")
		confirm "power off" && systemctl poweroff
		;;
esac
