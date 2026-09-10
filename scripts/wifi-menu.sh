#!/usr/bin/env bash
# Theme-consistent Wi-Fi picker: nmcli + wofi.
# Bound to the Waybar network pill (on-click). Uses the same wofi styling as
# the app launcher, so it inherits the Catppuccin theme automatically.

set -uo pipefail

wofi_menu() {
	wofi --dmenu --insensitive --cache-file /dev/null \
	     --width 380 --height 420 --prompt "${1:-Wi-Fi}"
}

# Signal strength (0-100) -> Nerd Font wifi glyph.
sig_icon() {
	local s=$1
	if   [ "$s" -ge 75 ]; then echo "󰤨"
	elif [ "$s" -ge 50 ]; then echo "󰤥"
	elif [ "$s" -ge 25 ]; then echo "󰤢"
	else                       echo "󰤟"
	fi
}

# --- radio off: offer to turn it on -------------------------------------------
if [ "$(nmcli -t -f WIFI radio)" = "disabled" ]; then
	[ "$(printf '󰖩  Turn Wi-Fi on' | wofi_menu 'Wi-Fi is off')" ] && nmcli radio wifi on
	exit 0
fi

nmcli device wifi rescan >/dev/null 2>&1 || true

active=$(nmcli -t -f ACTIVE,SSID device wifi | awk -F: '$1=="yes"{print $2; exit}')

# Fields ordered SIGNAL:SECURITY:SSID so only the SSID (last) can contain the
# escaped ':' that nmcli -t emits; signal and security never do.
build_list() {
	nmcli -t -f SIGNAL,SECURITY,SSID device wifi list --rescan no \
	| sort -t: -k1 -nr \
	| while IFS= read -r line; do
		sig=${line%%:*};  rest=${line#*:}
		sec=${rest%%:*};  ssid=${rest#*:}
		ssid=${ssid//\\:/:}
		[ -z "$ssid" ] && continue
		printf '%s\t%s\t%s\n' "$ssid" "$sig" "$sec"
	  done \
	| awk -F'\t' '!seen[$1]++'
}

menu=""
while IFS=$'\t' read -r ssid sig sec; do
	[ -z "$ssid" ] && continue
	mark="  "; [ "$ssid" = "$active" ] && mark="󰄬 "
	lock=" ";  [ -n "$sec" ] && lock="󰌾"
	# SSID is last, separated by a double space, so it survives extraction
	# even with a single space inside the name.
	menu+="$(printf '%s%s %s  %s\n' "$mark" "$(sig_icon "$sig")" "$lock" "$ssid")"$'\n'
done < <(build_list)

menu+="󰑓  Rescan"$'\n'
menu+="󰖪  Turn Wi-Fi off"

sel=$(printf '%s' "$menu" | wofi_menu "Wi-Fi")
[ -z "$sel" ] && exit 0

case "$sel" in
	*"Turn Wi-Fi off") nmcli radio wifi off; exit 0 ;;
	*"Rescan")         exec "$0" ;;
esac

ssid=${sel##*'  '}          # everything after the last double space
[ "$ssid" = "$active" ] && exit 0

# Known connection? bring it up without asking for a password again.
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
	nmcli connection up id "$ssid"
	exit $?
fi

secured=$(nmcli -t -f SSID,SECURITY device wifi list \
	| awk -F: -v s="$ssid" '$1==s && $2!=""{print "yes"; exit}')

if [ "$secured" = "yes" ]; then
	pass=$(wofi --dmenu --password --cache-file /dev/null \
	           --width 380 --height 60 --prompt "Password for $ssid")
	[ -z "$pass" ] && exit 0
	nmcli device wifi connect "$ssid" password "$pass"
else
	nmcli device wifi connect "$ssid"
fi
