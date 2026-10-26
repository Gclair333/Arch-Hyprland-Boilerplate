#!/usr/bin/env bash
# Settings panel: wofi menus behind the gear in the bar (and SUPER+I).
# Same wofi styling as the launcher, Wi-Fi picker and power menu. Not a daemon:
# it runs while a menu is open, then exits. Esc closes it from anywhere, Back
# goes up a level.
#
# Where your choices are saved:
#   ~/.config/hypr/settings.conf       keyboard, mouse, display, appearance.
#                                      hyprland.conf reads it last, so it wins.
#   ~/.config/hypr/settings-idle.conf  lock / screen-off / sleep timings,
#                                      read by hypridle.conf.
# Both appear on your first change and only hold what you've set here, one
# line each: delete a line (or use Reset to defaults) to get the default back.
# Sound devices are remembered by WirePlumber itself. The time zone and clock
# sync are system-wide, so those open a terminal that asks for your password.

set -uo pipefail

SCRIPTS="$HOME/.config/scripts"
HYPR="$HOME/.config/hypr"
SETTINGS="$HYPR/settings.conf"
IDLE_SETTINGS="$HYPR/settings-idle.conf"
IDLE_DEFAULTS="$HYPR/hypridle.conf"

# One menu at a time: clicking the gear again while it's open does nothing.
# Anything started from here that outlives the menu gets 9>&- so it doesn't
# hold this lock open.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/settings-menu.lock"
flock -n 9 || exit 0

# ---------------------------------------------------------------- menus ----

BACK="󰁍  Back"
ON="󰐾"     # radio button, picked
OFF="󰄰"    # radio button, not picked

# menu PROMPT ENTRY... — show a list; the picked entry lands in $REPLY.
# Esc closes Settings entirely, from any page.
menu() {
	local prompt=$1; shift
	local lines=$(( $# < 15 ? $# : 15 ))
	REPLY=$(printf '%s\n' "$@" | wofi --dmenu --insensitive --no-custom-entry \
		--cache-file /dev/null --define allow_markup=false \
		--width 520 --lines "$lines" --prompt "$prompt") || exit 0
	[ -n "$REPLY" ] || exit 0
}

# row ICON LABEL [VALUE] — one menu line, with the values lined up.
row() { printf '%s  %-29s %s' "$1" "$2" "$(trunc "${3:-}")"; }

trunc() { local s=$1; (( ${#s} > 30 )) && s="${s:0:29}…"; printf '%s' "$s"; }

onoff() { case "$1" in 1|true|yes) echo On ;; *) echo Off ;; esac; }
flip()  { case "$1" in 1|true|yes) echo false ;; *) echo true ;; esac; }

# choose PROMPT CURRENT LABEL VALUE [LABEL VALUE]... — a radio list. Sets
# $CHOSEN to the picked VALUE; returns 1 for Back. Long lists repeat the
# current choice at the top so it's visible without scrolling.
choose() {
	local prompt=$1 current=$2 i; shift 2
	local -a labels=() values=() entries=("$BACK")
	while (( $# >= 2 )); do labels+=("$1"); values+=("$2"); shift 2; done
	if (( ${#labels[@]} > 15 )); then
		for i in "${!labels[@]}"; do
			[ "${values[i]}" = "$current" ] && { entries+=("$ON  ${labels[i]}"); break; }
		done
	fi
	for i in "${!labels[@]}"; do
		if [ "${values[i]}" = "$current" ]; then entries+=("$ON  ${labels[i]}")
		else entries+=("$OFF  ${labels[i]}"); fi
	done
	menu "$prompt" "${entries[@]}"
	for i in "${!labels[@]}"; do
		case "$REPLY" in
			"$ON  ${labels[i]}"|"$OFF  ${labels[i]}") CHOSEN=${values[i]}; return 0 ;;
		esac
	done
	return 1
}

# message TITLE LINE... — some text and an OK.
message() { local title=$1; shift; menu "$title" "$@" "󰄬  OK"; }

# terminal TITLE BODY [ARG]... — run BODY (sh, given ARGs as $1...) in a
# kitty window that stays open at the end so you can read what happened.
# BODY is a function body: `return` from it, don't `exit`. Callers exit
# straight after, since an open menu would keep the keyboard from kitty.
terminal() {
	local title=$1; shift
	setsid -f kitty --title "$title" sh -c '
		eval "main() {
$1
}"
		shift
		main "$@"; status=$?
		echo
		if [ "$status" -eq 0 ]; then echo "Done."; else echo "That did not work (exit code $status)."; fi
		printf "Press Enter to close this window. "; read -r _' sh "$@" 9>&- >/dev/null 2>&1
}

# -------------------------------------------------------------- storage ----

# Which setting a line holds: its key, except monitor lines, of which there's
# one per display ("monitor:eDP-1").
AWK_ID='
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function id_of(l,   k, f) {
	if (l ~ /^[ \t]*#/ || index(l, "=") == 0) return ""
	k = trim(substr(l, 1, index(l, "=") - 1))
	if (k == "monitor") { split(substr(l, index(l, "=") + 1), f, ","); k = k ":" trim(f[1]) }
	return k
}'

new_settings_file() {
	if [ "$1" = "$IDLE_SETTINGS" ]; then
		cat > "$1" <<-'EOF'
		# Your lock and sleep timings from the Settings menu (the gear in the bar, or
		# SUPER+I), in seconds; empty = off. hypridle.conf reads this right after its
		# own defaults, so what's here wins. Delete a line (or this file) to go back
		# to the default, or use "Reset to defaults" in the menu.
		# The next line keeps typos in here visible as config errors:
		# hyprlang noerror false
		EOF
	else
		cat > "$1" <<-'EOF'
		# Your choices from the Settings menu (the gear in the bar, or SUPER+I).
		# hyprland.conf reads this file last, so what's here wins over what it says.
		# One setting per line. Delete a line (or this file) to go back to the
		# default, or use "Reset to defaults" in the menu.
		# The next line keeps typos in here visible as config errors:
		# hyprlang noerror false
		EOF
	fi
}

# conf_put FILE ID LINE — replace the line holding ID, or add it at the end.
# Written to a temp file and moved into place, because Hyprland reloads
# settings.conf the moment it changes and must never read half a file.
conf_put() {
	[ -f "$1" ] || new_settings_file "$1"
	local tmp
	tmp=$(mktemp "$1.XXXXXX") || return 1
	awk -v id="$2" -v new="$3" "$AWK_ID"'
		id_of($0) == id { if (!done) print new; done = 1; next }
		{ print }
		END { if (!done) print new }' "$1" > "$tmp" && mv -f "$tmp" "$1"
}

# conf_del FILE ID — drop the line holding ID.
conf_del() {
	[ -f "$1" ] || return 0
	local tmp
	tmp=$(mktemp "$1.XXXXXX") || return 1
	awk -v id="$2" "$AWK_ID"' id_of($0) != id' "$1" > "$tmp" && mv -f "$tmp" "$1"
}

# conf_get FILE ID — the value on the line holding ID; fails if there's none.
conf_get() {
	[ -f "$1" ] || return 1
	awk -v id="$2" "$AWK_ID"'
		id_of($0) == id { v = substr($0, index($0, "=") + 1); sub(/#.*/, "", v); found = 1 }
		END { if (!found) exit 1; print trim(v) }' "$1"
}

# hypr_get OPTION — Hyprland's live value: "1", "0.94", "us", "5 5 5 5", ...
hypr_get() {
	hyprctl getoption "$1" -j 2>/dev/null |
		jq -r '(.int // .float // .str // .custom // "") | tostring | sub("^\\[\\[EMPTY\\]\\]$"; "")'
}

# hypr_set OPTION VALUE — apply it now, and save it in settings.conf.
hypr_set() {
	local out
	out=$(hyprctl keyword "$1" "$2" 2>&1)
	if [ "$out" != "ok" ]; then
		message "Couldn't change that" "󰅚  $1 = $2" "    $out"
		return 1
	fi
	conf_put "$SETTINGS" "$1" "$1 = $2"
}

num() { awk -v x="$1" 'BEGIN { printf "%g", x + 0 }'; }

# ----------------------------------------------------- lock screen & sleep --

# idle_get NAME — a hypridle timing, from settings-idle.conf or else the
# default in hypridle.conf. Empty means that step is off.
idle_get() { conf_get "$IDLE_SETTINGS" "\$$1" || conf_get "$IDLE_DEFAULTS" "\$$1"; }

restart_hypridle() {
	pkill -x hypridle
	local i
	for i in $(seq 20); do pgrep -x hypridle >/dev/null || break; sleep 0.1; done
	# Through Hyprland, so it runs exactly like the exec-once at login.
	hyprctl dispatch exec hypridle >/dev/null
}

# fmt_secs SECONDS — "45 s", "5 min", "5½ min", "1 hour"; empty = "Never".
fmt_secs() {
	local s=${1:-}
	if [ -z "$s" ]; then echo "Never"
	elif (( s < 60 )); then echo "$s s"
	elif (( s % 3600 == 0 )); then (( s == 3600 )) && echo "1 hour" || echo "$(( s / 3600 )) hours"
	elif (( s % 60 == 0 )); then echo "$(( s / 60 )) min"
	elif (( s % 60 == 30 )); then echo "$(( s / 60 ))½ min"
	else echo "$s s"; fi
}

# pick_duration PROMPT CURRENT CHOICE... — radio list of times. A current
# value that isn't one of the choices (the 5½-minute screen-off default, or
# a hand edit) is slotted in, in order, so it still shows as picked.
pick_duration() {
	local prompt=$1 current=$2 v; shift 2
	local -a args=()
	while read -r v; do args+=("$(fmt_secs "$v")" "$v"); done < <(
		printf '%s\n' "$@" "$current" | grep -E '^[0-9]+$' | sort -n -u)
	args+=("Never" "")
	choose "$prompt" "$current" "${args[@]}"
}

TIMES=(60 120 180 300 600 900 1800 3600)
SLEEP_TIMES=(300 600 900 1800 3600 7200)

# first_of A B — the earlier of two timings, ignoring ones that are off.
first_of() {
	if [ -z "$1" ]; then echo "$2"
	elif [ -z "$2" ] || (( $1 < $2 )); then echo "$1"
	else echo "$2"; fi
}

# The dim is a warning shot: a minute before the screen locks or turns off,
# whichever is first (halfway there, for timeouts of 2 minutes or less).
dim_for() { # lock_after screen_off_after
	local first
	first=$(first_of "$1" "$2")
	[ -n "$first" ] || return 0
	(( first <= 120 )) && echo $(( first / 2 )) || echo $(( first - 60 ))
}

lock_page() {
	local lock off sleep_after dim awake dim_on first dim_text
	while :; do
		lock=$(idle_get lock_after)
		off=$(idle_get screen_off_after)
		sleep_after=$(idle_get sleep_after)
		dim=$(idle_get dim_after)
		awake=$(idle_get ok_to_idle)
		first=$(first_of "$lock" "$off")

		# With nothing scheduled there's nothing to warn about, so dim reads
		# Off, but it isn't switched off: it returns with the next lock time.
		dim_on=0
		if [ -n "$dim" ] || [ -z "$first" ]; then dim_on=1; fi
		dim_text=Off
		if [ -n "$dim" ]; then
			dim_text=On
			[ -n "$first" ] && (( first > dim )) && dim_text="On, $(fmt_secs $(( first - dim ))) before"
		fi

		local -a e=("$BACK"
			"$(row 󰌾 "Lock the screen after" "$(fmt_secs "$lock")")"
			"$(row 󰶐 "Turn the screen off after" "$(fmt_secs "$off")")"
			"$(row 󰒲 "Sleep after" "$(fmt_secs "$sleep_after")")"
			"$(row 󰃞 "Dim the screen first" "$dim_text")")
		command -v mpvpaper >/dev/null &&
			e+=("$(row 󰎁 "Stay awake during anime" "$([ -n "$awake" ] && echo On || echo Off)")")
		e+=("$(row 󰷛 "Lock now")" "$(row 󰌋 "Change my password")")
		menu "Lock screen & sleep" "${e[@]}"

		case "$REPLY" in
			"$BACK") return ;;
			"󰌾  Lock the screen after"*)
				pick_duration "Lock the screen after" "$lock" "${TIMES[@]}" || continue
				lock=$CHOSEN ;;
			"󰶐  Turn the screen off after"*)
				pick_duration "Turn the screen off after" "$off" "${TIMES[@]}" || continue
				off=$CHOSEN ;;
			"󰒲  Sleep after"*)
				pick_duration "Sleep after" "$sleep_after" "${SLEEP_TIMES[@]}" || continue
				conf_put "$IDLE_SETTINGS" '$sleep_after' "\$sleep_after = $CHOSEN"
				restart_hypridle
				continue ;;
			"󰃞  Dim the screen first"*)
				[ -n "$dim" ] && dim_on=0 || dim_on=1 ;;
			"󰎁  Stay awake during anime"*)
				# On = hypridle.conf's default check, so just drop the override.
				if [ -n "$awake" ]; then conf_put "$IDLE_SETTINGS" '$ok_to_idle' '$ok_to_idle ='
				else conf_del "$IDLE_SETTINGS" '$ok_to_idle'; fi
				restart_hypridle
				continue ;;
			"󰷛  Lock now"*)
				loginctl lock-session
				exit 0 ;;
			"󰌋  Change my password"*)
				terminal "Change password" '
					echo "Type your CURRENT password first, then the new one twice."
					echo "Nothing shows while you type a password. That is normal."
					echo
					passwd'
				exit 0 ;;
			*) continue ;;
		esac

		# Lock, screen-off or dim changed: save all three, since the dim
		# time follows the other two.
		dim=""
		(( dim_on )) && dim=$(dim_for "$lock" "$off")
		conf_put "$IDLE_SETTINGS" '$lock_after' "\$lock_after = $lock"
		conf_put "$IDLE_SETTINGS" '$screen_off_after' "\$screen_off_after = $off"
		conf_put "$IDLE_SETTINGS" '$dim_after' "\$dim_after = $dim"
		restart_hypridle
	done
}

# --------------------------------------------------------------- display ----

# The saved rule for a display as "mode<TAB>scale"; preferred/auto if none.
mon_rule() {
	local v
	v=$(conf_get "$SETTINGS" "monitor:$1") || { printf 'preferred\tauto'; return; }
	awk -F, '{ for (i = 1; i <= NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
	           printf "%s\t%s", ($2 == "" ? "preferred" : $2), ($4 == "" ? "auto" : $4) }' <<<"$v"
}

mon_apply() { # name mode scale
	local rule="$1, $2, auto, $3" out
	out=$(hyprctl keyword monitor "$rule" 2>&1)
	if [ "$out" != "ok" ]; then
		message "Couldn't change the display" "󰅚  $out"
		return 1
	fi
	# preferred + auto is what hyprland.conf does anyway: nothing to save.
	if [ "$2" = preferred ] && [ "$3" = auto ]; then conf_del "$SETTINGS" "monitor:$1"
	else conf_put "$SETTINGS" "monitor:$1" "monitor = $rule"; fi
	sleep 0.5   # let the display settle before the next menu draws on it
}

# A new mode could leave a screen black, so it reverts in 15 seconds unless
# you say it looks right.
keep_or_revert() { # name old_mode old_scale
	local answer
	answer=$(printf '%s\n' "󰄬  Keep this" "󰜺  Go back (happens by itself in 15 s)" |
		timeout 15 wofi --dmenu --no-custom-entry --cache-file /dev/null \
			--define allow_markup=false --width 520 --lines 2 \
			--prompt "Does the display look right?") || answer=""
	case "$answer" in "󰄬  Keep this") return 0 ;; esac
	mon_apply "$1" "$2" "$3"
}

monitor_page() { # name
	local name=$1 m w h scale hz rate mode rscale s v
	while :; do
		m=$(hyprctl monitors -j | jq --arg n "$name" '.[] | select(.name == $n)')
		[ -n "$m" ] || return
		w=$(jq .width <<<"$m"); h=$(jq .height <<<"$m")
		scale=$(jq '.scale * 100 | round / 100' <<<"$m")
		hz=$(jq '.refreshRate | round' <<<"$m")
		rate=$(jq -r '.refreshRate * 100 | round / 100 | tostring' <<<"$m")
		IFS=$'\t' read -r mode rscale < <(mon_rule "$name")

		local -a rates sizes
		# Fastest first. Sorted as numbers: as text, 60 would beat 120.
		mapfile -t rates < <(jq -r --arg r "${w}x$h@" '[.availableModes[] | select(startswith($r))
			| sub("Hz$"; "")] | unique | sort_by(sub(".*@"; "") | tonumber) | reverse[]' <<<"$m")
		mapfile -t sizes < <(jq -r '[.availableModes[] | sub("@.*"; "")] | unique
			| sort_by(split("x") | map(tonumber)) | reverse[]' <<<"$m")

		local -a e=("$BACK" "$(row 󰍹 "Scale (size of everything)" "${scale}×$([ "$rscale" = auto ] && echo ", automatic")")")
		(( ${#rates[@]} > 1 )) && e+=("$(row 󰑓 "Refresh rate" "$hz Hz")")
		(( ${#sizes[@]} > 1 )) && e+=("$(row 󰹑 "Resolution" "${w}×$h")")
		[[ $name == eDP* ]] && [ -n "$("$SCRIPTS/backlight" get)" ] &&
			e+=("$(row 󰃞 "Brightness" "$("$SCRIPTS/backlight" get)%")")
		menu "Display: $name" "${e[@]}"

		case "$REPLY" in
			"$BACK") return ;;
			"󰍹  Scale"*)
				local -a args=()
				for s in 1 1.25 1.5 1.75 2; do
					# Hyprland only takes scales that divide the resolution evenly.
					awk -v w="$w" -v h="$h" -v s="$s" \
						'BEGIN { exit !(w / s == int(w / s) && h / s == int(h / s)) }' || continue
					case $s in 1) v=" (smallest, most room)" ;; 2) v=" (largest)" ;; *) v="" ;; esac
					args+=("${s}×$v" "$s")
				done
				args+=("Automatic (Hyprland picks)" "auto")
				choose "Scale" "$rscale" "${args[@]}" || continue
				mon_apply "$name" "$mode" "$CHOSEN" ;;
			"󰑓  Refresh rate"*)
				local -a args=()
				for v in "${rates[@]}"; do
					s=${v#*@}
					args+=("$(printf '%.0f Hz' "$s")$( [ "$v" = "${rates[0]}" ] && echo " (smoothest)")$( [ "$v" = "${rates[-1]}" ] && echo " (saves battery)")" "$v")
				done
				choose "Refresh rate" "$(printf '%sx%s@%.2f' "$w" "$h" "$rate")" "${args[@]}" || continue
				mon_apply "$name" "$CHOSEN" "$rscale" && keep_or_revert "$name" "$mode" "$rscale" ;;
			"󰹑  Resolution"*)
				local -a args=()
				for v in "${sizes[@]}"; do args+=("${v/x/×}" "$v"); done
				choose "Resolution" "${w}x$h" "${args[@]}" || continue
				# Highest refresh rate the display offers at that size.
				v=$(jq -r --arg r "$CHOSEN@" '[.availableModes[] | select(startswith($r)) | sub("Hz$"; "")]
					| sort_by(sub(".*@"; "") | tonumber) | last' <<<"$m")
				mon_apply "$name" "$v" "$rscale" && keep_or_revert "$name" "$mode" "$rscale" ;;
			"󰃞  Brightness"*)
				choose "Brightness (the bar's slider does this too)" "" \
					"100%" 100 "75%" 75 "50%" 50 "25%" 25 "10%" 10 || continue
				"$SCRIPTS/backlight" set "$CHOSEN" ;;
		esac
	done
}

display_page() {
	local mons name desc
	while :; do
		mons=$(hyprctl monitors -j)
		if (( $(jq length <<<"$mons") == 1 )); then
			monitor_page "$(jq -r '.[0].name' <<<"$mons")"
			return
		fi
		local -a args=()
		while IFS=$'\t' read -r name desc; do args+=("$name  $desc" "$name"); done < <(
			jq -r '.[] | [.name, .description] | @tsv' <<<"$mons")
		choose "Which display?" "" "${args[@]}" || return
		monitor_page "$CHOSEN"
	done
}

# ----------------------------------------------------------------- sound ----

# pick_device PROMPT JSON CURRENT — radio list of sinks or sources.
pick_device() {
	local -a args=()
	local -A seen=()
	local name desc
	while IFS=$'\t' read -r name desc; do
		# Two devices with the same description get their names attached.
		[ -n "${seen[$desc]:-}" ] && desc="$desc ($name)"
		seen[$desc]=1
		args+=("$desc" "$name")
	done < <(jq -r '.[] | [.name, .description] | @tsv' <<<"$2")
	choose "$1" "$3" "${args[@]}"
}

sound_page() {
	local sinks sources sink src out_desc in_desc mic
	while :; do
		sinks=$(pactl -f json list sinks 2>/dev/null) || sinks='[]'
		# Monitor sources are "what's playing", not microphones.
		sources=$(pactl -f json list sources 2>/dev/null | jq '[.[] | select(.monitor_source == "")]') || sources='[]'
		sink=$(pactl get-default-sink 2>/dev/null)
		src=$(pactl get-default-source 2>/dev/null)
		out_desc=$(jq -r --arg n "$sink" '.[] | select(.name == $n) | .description' <<<"$sinks")
		in_desc=$(jq -r --arg n "$src" '.[] | select(.name == $n) | .description' <<<"$sources")
		mic=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)

		local -a e=("$BACK"
			"$(row 󰓃 "Output (speakers)" "${out_desc:-none}")"
			"$(row 󰍬 "Input (microphone)" "${in_desc:-none}")")
		[ -n "$mic" ] && e+=("$(row 󰍭 "Microphone" "$(case $mic in *MUTED*) echo Muted ;; *) echo On ;; esac)")")
		menu "Sound" "${e[@]}"

		case "$REPLY" in
			"$BACK") return ;;
			"󰓃  Output"*) pick_device "Output" "$sinks" "$sink" && pactl set-default-sink "$CHOSEN" ;;
			"󰍬  Input"*)  pick_device "Input" "$sources" "$src" && pactl set-default-source "$CHOSEN" ;;
			"󰍭  Microphone"*) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
		esac
	done
}

# -------------------------------------------------------------- keyboard ----

# Every layout and variant xkb knows, as "Description<TAB>layout<TAB>variant".
layout_list() {
	[ -n "${LAYOUTS:-}" ] || LAYOUTS=$(awk '
		/^! / { sec = $2; next }
		sec == "layout"  && NF >= 2 && $1 != "custom" { l = $1; $1 = ""; sub(/^ +/, ""); print $0 "\t" l "\t" }
		sec == "variant" && NF >= 3 { v = $1; l = $2; sub(/:$/, "", l); $1 = $2 = ""; sub(/^ +/, ""); print $0 "\t" l "\t" v }
		' /usr/share/X11/xkb/rules/evdev.lst 2>/dev/null | sort -f -t $'\t' -k1,1)
	printf '%s\n' "$LAYOUTS"
}

layout_name() { # layout variant
	local d
	d=$(layout_list | awk -F'\t' -v l="$1" -v v="$2" '$2 == l && $3 == v { print $1; exit }')
	echo "${d:-$1${2:+ ($2)}}"
}

keyboard_page() {
	local layout variant delay rate numlock desc l v
	while :; do
		layout=$(hypr_get input:kb_layout); variant=$(hypr_get input:kb_variant)
		delay=$(hypr_get input:repeat_delay); rate=$(hypr_get input:repeat_rate)
		numlock=$(hypr_get input:numlock_by_default)
		menu "Keyboard" "$BACK" \
			"$(row 󰌌 "Layout" "$(layout_name "$layout" "$variant")")" \
			"$(row 󰔟 "Repeat delay" "$delay ms")" \
			"$(row 󰑓 "Repeat speed" "$rate per second")" \
			"$(row 󰎠 "Num Lock on at login" "$(onoff "$numlock")")" \
			"$(row 󰘳 "Keyboard shortcuts" "SUPER + /")"

		case "$REPLY" in
			"$BACK") return ;;
			"󰘳  Keyboard shortcuts"*) exec "$SCRIPTS/keybinds-menu.sh" 9>&- ;;
			"󰌌  Layout"*)
				local -a args=()
				while IFS=$'\t' read -r desc l v; do args+=("$desc" "$l:$v"); done < <(layout_list)
				choose "Layout (type to search)" "$layout:$variant" "${args[@]}" || continue
				l=${CHOSEN%%:*} v=${CHOSEN#*:}
				# Variant cleared first: the old one may not exist for the new layout.
				hypr_set input:kb_variant "" && hypr_set input:kb_layout "$l" &&
					hypr_set input:kb_variant "$v" ;;
			"󰔟  Repeat delay"*)
				choose "Hold a key this long before it repeats" "$delay" \
					"Short (250 ms)" 250 "Medium (400 ms)" 400 "Default (600 ms)" 600 "Long (800 ms)" 800 &&
					hypr_set input:repeat_delay "$CHOSEN" ;;
			"󰑓  Repeat speed"*)
				choose "Repeat speed" "$rate" \
					"Slow (15 per second)" 15 "Default (25 per second)" 25 \
					"Fast (40 per second)" 40 "Very fast (60 per second)" 60 &&
					hypr_set input:repeat_rate "$CHOSEN" ;;
			"󰎠  Num Lock"*) hypr_set input:numlock_by_default "$(flip "$numlock")" ;;
		esac
	done
}

# --------------------------------------------------------- mouse & touchpad --

SPEEDS=("Slowest" -0.75 "Slower" -0.5 "Slow" -0.25 "Default" 0 "Fast" 0.25 "Faster" 0.5 "Fastest" 0.75)

speed_name() {
	local i
	for (( i = 0; i < ${#SPEEDS[@]}; i += 2 )); do
		[ "${SPEEDS[i+1]}" = "$1" ] && { echo "${SPEEDS[i]}"; return; }
	done
	echo "$1"
}

mouse_page() {
	local touchpad sens accel nat tap tnat dwt
	touchpad=$(hyprctl devices -j | jq '[.mice[] | select(.name | test("touchpad"; "i"))] | length')
	while :; do
		sens=$(num "$(hypr_get input:sensitivity)")
		accel=$(hypr_get input:accel_profile)
		nat=$(hypr_get input:natural_scroll)
		local -a e=("$BACK"
			"$(row 󰍽 "Pointer speed" "$(speed_name "$sens")")"
			"$(row 󰍽 "Mouse acceleration" "$([ "$accel" = flat ] && echo Off || echo On)")"
			"$(row 󰍽 "Reverse the scroll wheel" "$(onoff "$nat")")")
		if (( touchpad > 0 )); then
			tap=$(hypr_get input:touchpad:tap-to-click)
			tnat=$(hypr_get input:touchpad:natural_scroll)
			dwt=$(hypr_get input:touchpad:disable_while_typing)
			e+=("$(row 󰟸 "Tap to click" "$(onoff "$tap")")"
				"$(row 󰟸 "Natural scrolling (touchpad)" "$(onoff "$tnat")")"
				"$(row 󰟸 "Ignore touchpad while typing" "$(onoff "$dwt")")")
		fi
		menu "Mouse & touchpad" "${e[@]}"

		case "$REPLY" in
			"$BACK") return ;;
			"󰍽  Pointer speed"*)
				choose "Pointer speed" "$sens" "${SPEEDS[@]}" && hypr_set input:sensitivity "$CHOSEN" ;;
			# Empty = libinput's default, which is acceleration on.
			"󰍽  Mouse acceleration"*)
				hypr_set input:accel_profile "$([ "$accel" = flat ] && echo "" || echo flat)" ;;
			"󰍽  Reverse the scroll wheel"*) hypr_set input:natural_scroll "$(flip "$nat")" ;;
			"󰟸  Tap to click"*) hypr_set input:touchpad:tap-to-click "$(flip "$tap")" ;;
			"󰟸  Natural scrolling"*) hypr_set input:touchpad:natural_scroll "$(flip "$tnat")" ;;
			"󰟸  Ignore touchpad"*) hypr_set input:touchpad:disable_while_typing "$(flip "$dwt")" ;;
		esac
	done
}

# ------------------------------------------------------------- appearance ----

appearance_page() {
	local anim blur shadow gaps round fade
	while :; do
		anim=$(hypr_get animations:enabled)
		blur=$(hypr_get decoration:blur:enabled)
		shadow=$(hypr_get decoration:shadow:enabled)
		gaps=$(hypr_get general:gaps_out); gaps=${gaps%% *}
		round=$(hypr_get decoration:rounding)
		fade=$(num "$(hypr_get decoration:inactive_opacity)")
		menu "Appearance" "$BACK" \
			"$(row 󰗘 "Animations" "$(onoff "$anim")")" \
			"$(row 󰂵 "Blur (frosted glass)" "$(onoff "$blur")")" \
			"$(row 󰘷 "Window shadows" "$(onoff "$shadow")")" \
			"$(row 󰕰 "Gaps between windows" "$(case $gaps in 0) echo None ;; 6) echo Small ;; 10) echo Normal ;; 20) echo Large ;; *) echo "$gaps px" ;; esac)")" \
			"$(row 󰢡 "Rounded corners" "$(case $round in 0) echo Square ;; 5) echo Slight ;; 10) echo Round ;; 16) echo "Very round" ;; *) echo "$round px" ;; esac)")" \
			"$(row 󰗘 "Fade unfocused windows" "$([ "$fade" = 1 ] && echo Off || echo On)")"

		case "$REPLY" in
			"$BACK") return ;;
			"󰗘  Animations"*) hypr_set animations:enabled "$(flip "$anim")" ;;
			"󰂵  Blur"*) hypr_set decoration:blur:enabled "$(flip "$blur")" ;;
			"󰘷  Window shadows"*) hypr_set decoration:shadow:enabled "$(flip "$shadow")" ;;
			"󰕰  Gaps"*)
				# Inner gaps are half the outer ones, as in hyprland.conf.
				choose "Gaps between windows" "$gaps" "None" 0 "Small" 6 "Normal" 10 "Large" 20 &&
					hypr_set general:gaps_in "$(( CHOSEN / 2 ))" && hypr_set general:gaps_out "$CHOSEN" ;;
			"󰢡  Rounded corners"*)
				choose "Rounded corners" "$round" "Square" 0 "Slight" 5 "Round" 10 "Very round" 16 &&
					hypr_set decoration:rounding "$CHOSEN" ;;
			"󰗘  Fade unfocused"*)
				hypr_set decoration:inactive_opacity "$([ "$fade" = 1 ] && echo 0.94 || echo 1.0)" ;;
		esac
	done
}

# ------------------------------------------------------------ date & time ----

pick_timezone() { # current
	local z
	local -a args=(
		"US Eastern (New York)" America/New_York
		"US Central (Chicago)" America/Chicago
		"US Mountain (Denver)" America/Denver
		"US Arizona (Phoenix, no daylight saving)" America/Phoenix
		"US Pacific (Los Angeles)" America/Los_Angeles
		"US Alaska (Anchorage)" America/Anchorage
		"US Hawaii (Honolulu)" Pacific/Honolulu
		"UK (London)" Europe/London
		"Central Europe (Berlin, Paris, Rome)" Europe/Berlin
	)
	# Underscores shown as spaces, so typing "new york" finds America/New_York.
	while IFS= read -r z; do args+=("${z//_/ }" "$z"); done < <(timedatectl list-timezones 2>/dev/null)
	choose "Time zone (type a city to search)" "$1" "${args[@]}"
}

datetime_page() {
	local tz ntp synced
	while :; do
		tz=$(timedatectl show -p Timezone --value 2>/dev/null)
		ntp=$(timedatectl show -p NTP --value 2>/dev/null)
		synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
		menu "Date & time" "$BACK" \
			"$(row 󰥔 "Time zone" "$tz")" \
			"$(row 󰔟 "Set the time automatically" "$(onoff "$ntp")$([ "$ntp" = yes ] && [ "$synced" != yes ] && echo ", not synced yet")")" \
			"$(row 󰃭 "It's now" "$(date '+%a %-d %b, %-I:%M %p')")"

		case "$REPLY" in
			"$BACK") return ;;
			"󰥔  Time zone"*)
				pick_timezone "$tz" || continue
				[ "$CHOSEN" != "$tz" ] || continue
				terminal "Time zone" '
					echo "Changing the time zone to $1."
					echo "It is a system-wide setting, so sudo asks for your password."
					echo
					sudo timedatectl set-timezone "$1" || return
					pkill -USR2 -x waybar   # redraw the bar clock now, not at the next minute
					timedatectl status' "$CHOSEN"
				exit 0 ;;
			"󰔟  Set the time automatically"*)
				terminal "Automatic time" '
					if [ "$1" = true ]; then
						echo "Turning on automatic time: the clock keeps itself right using internet time servers."
					else
						echo "Turning off automatic time."
					fi
					echo "It is a system-wide setting, so sudo asks for your password."
					echo
					sudo timedatectl set-ntp "$1" || return
					sleep 2
					timedatectl status' "$(flip "$ntp")"
				exit 0 ;;
		esac
	done
}

# -------------------------------------------------------------- wallpaper ----

wallpaper_page() {
	local ipc="$SCRIPTS/mpvpaper-ipc" paused muted
	while :; do
		local -a e=("$BACK")
		if paused=$("$ipc" get pause 2>/dev/null); then
			muted=$("$ipc" get mute 2>/dev/null)
			e+=("$(row 󰏤 "Play / pause" "$([ "$paused" = true ] && echo Paused || echo Playing)")"
				"$(row 󰕾 "Wallpaper sound" "$([ "$muted" = true ] && echo Muted || echo On)")")
		else
			e+=("$(row 󰐊 "Start the video wallpaper")")
		fi
		command -v ani-cli >/dev/null &&
			e+=("$(row 󰎁 "Watch anime" "SUPER+A")" "$(row 󰑐 "Resume the last episode" "SUPER+R")")
		menu "Wallpaper" "${e[@]}"

		case "$REPLY" in
			"$BACK") return ;;
			"󰏤  Play / pause"*) "$ipc" cycle pause ;;
			"󰕾  Wallpaper sound"*) "$SCRIPTS/wallpaper-audio" toggle ;;
			"󰐊  Start"*) "$SCRIPTS/wallpaper-start" --quiet 9>&- ;;
			"󰎁  Watch anime"*) setsid -f kitty -e "$SCRIPTS/watch-anime" 9>&- >/dev/null 2>&1; exit 0 ;;
			"󰑐  Resume"*) setsid -f kitty -e "$SCRIPTS/wallpaper-resume" 9>&- >/dev/null 2>&1; exit 0 ;;
		esac
	done
}

# ------------------------------------------------------------------ about ----

# Rows for the About page, plus the full text each one copies (rows are cut
# short to fit the menu).
INFO_ROWS=() INFO_TEXT=()
add_info() { INFO_ROWS+=("$(row "$1" "$2" "$3")"); INFO_TEXT+=("$2: $3"); }

about_page() {
	local mem disk bat b i
	INFO_ROWS=() INFO_TEXT=()
	mem=$(free -b | awk '/^Mem:/ { printf "%.1f GiB, %.1f GiB free", $2 / 2^30, $7 / 2^30 }')
	disk=$(df -h --output=target,avail,size / /home 2>/dev/null |
		awk 'NR > 1 && !seen[$1]++ { printf "%s%s %s free of %s", (n++ ? ", " : ""), $1, $2, $3 }')
	for b in /sys/class/power_supply/BAT*; do
		[ -r "$b/capacity" ] || continue
		bat="$(cat "$b/capacity")%, $(tr '[:upper:]' '[:lower:]' < "$b/status")"
		# Health: today's full charge against what it held when new.
		if [ -r "$b/energy_full" ] && [ -r "$b/energy_full_design" ]; then
			bat+=", health $(( $(cat "$b/energy_full") * 100 / $(cat "$b/energy_full_design") ))%"
		elif [ -r "$b/charge_full" ] && [ -r "$b/charge_full_design" ]; then
			bat+=", health $(( $(cat "$b/charge_full") * 100 / $(cat "$b/charge_full_design") ))%"
		fi
		break
	done
	add_info 󰌢 "Computer name" "$(hostnamectl hostname 2>/dev/null || cat /etc/hostname)"
	add_info 󰣇 "System" "$(. /etc/os-release; echo "${PRETTY_NAME:-Linux}")"
	add_info 󰣇 "Kernel" "$(uname -r)"
	add_info 󰕮 "Desktop" "Hyprland $(hyprctl version -j 2>/dev/null | jq -r .version)"
	add_info 󰍛 "Processor" "$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n 1)"
	add_info 󰍛 "Memory" "$mem"
	add_info 󰋊 "Storage" "$disk"
	[ -n "${bat:-}" ] && add_info 󰁹 "Battery" "$bat"
	add_info 󰔟 "Running for" "$(uptime -p | sed 's/^up //')"
	add_info 󰏗 "Packages" "$(pacman -Qq | wc -l) installed"

	local prompt="About this computer (pick a line to copy it)"
	while :; do
		menu "$prompt" "$BACK" "$(row 󰆏 "Copy all of this")" "${INFO_ROWS[@]}"
		case "$REPLY" in
			"$BACK") return ;;
			"󰆏  Copy all"*) printf '%s\n' "${INFO_TEXT[@]}" | wl-copy ;;
			*)
				for i in "${!INFO_ROWS[@]}"; do
					[ "$REPLY" = "${INFO_ROWS[i]}" ] && printf '%s\n' "${INFO_TEXT[i]}" | wl-copy
				done ;;
		esac
		prompt="Copied. Paste it anywhere with Ctrl+V"
	done
}

# ----------------------------------------------------------- everything else --

update_system() {
	terminal "System update" '
		echo "Updating everything installed from the official Arch repos."
		echo "sudo asks for your password, then pacman lists what will change and asks before doing it."
		echo
		sudo pacman -Syu || return
		if command -v yay >/dev/null 2>&1; then
			echo
			printf "Also update the AUR packages (ani-cli, mpvpaper, ...) with yay? [y/N] "
			read -r answer
			case "$answer" in [yY]*) yay -Sua ;; esac
		fi'
	exit 0
}

reset_page() {
	menu "Reset to defaults?" "$BACK" \
		"󰦛  Yes, undo everything changed in this menu" \
		"      Time zone, clock sync and sound devices stay as they are."
	case "$REPLY" in
		"󰦛  Yes"*)
			rm -f "$SETTINGS" "$IDLE_SETTINGS"
			hyprctl reload >/dev/null
			restart_hypridle ;;
	esac
}

main_page() {
	local lock tz kb
	layout_list >/dev/null   # fill the layout cache here, outside any $( ) subshell
	while :; do
		lock=$(idle_get lock_after)
		tz=$(timedatectl show -p Timezone --value 2>/dev/null)
		kb=$(layout_name "$(hypr_get input:kb_layout)" "$(hypr_get input:kb_variant)")
		local -a e=(
			"$(row 󰌾 "Lock screen & sleep" "$([ -n "$lock" ] && echo "Locks after $(fmt_secs "$lock")" || echo "Never locks")")"
			"$(row 󰍹 "Display" "$(hyprctl monitors -j | jq -r 'if length == 1 then .[0] |
				"\(.scale * 100 | round / 100)× · \(.refreshRate | round) Hz" else "\(length) displays" end')")"
			"$(row 󰕾 "Sound" "$(pactl -f json list sinks 2>/dev/null | jq -r --arg n "$(pactl get-default-sink 2>/dev/null)" \
				'.[] | select(.name == $n) | .description')")"
			"$(row 󰌌 "Keyboard" "$kb")"
			"$(row 󰍽 "Mouse & touchpad")"
			"$(row 󰏘 "Appearance")"
			"$(row 󰥔 "Date & time" "$tz")"
			"$(row 󰤨 "Wi-Fi")")
		command -v mpvpaper >/dev/null && e+=("$(row 󰸉 "Wallpaper")")
		e+=("$(row 󰋽 "About this computer")"
			"$(row 󰚰 "Update the system")"
			"$(row 󰦛 "Reset to defaults")")
		menu "Settings" "${e[@]}"

		case "$REPLY" in
			"󰌾  Lock screen & sleep"*) lock_page ;;
			"󰍹  Display"*) display_page ;;
			"󰕾  Sound"*) sound_page ;;
			"󰌌  Keyboard"*) keyboard_page ;;
			"󰍽  Mouse & touchpad"*) mouse_page ;;
			"󰏘  Appearance"*) appearance_page ;;
			"󰥔  Date & time"*) datetime_page ;;
			"󰤨  Wi-Fi"*) exec "$SCRIPTS/wifi-menu.sh" 9>&- ;;
			"󰸉  Wallpaper"*) wallpaper_page ;;
			"󰋽  About this computer"*) about_page ;;
			"󰚰  Update the system"*) update_system ;;
			"󰦛  Reset to defaults"*) reset_page ;;
		esac
	done
}

main_page
