#!/usr/bin/env bash
# One launcher for everything: apps, power, calculator, commands

# ---- build app list from .desktop files ----
declare -A APPS
while IFS='|' read -r name id; do
    APPS["$name"]="$id"
done < <(
    for f in /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop; do
        [ -f "$f" ] || continue
        grep -q '^NoDisplay=true' "$f" && continue
        n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
        [ -n "$n" ] && echo "$n|$(basename "$f" .desktop)"
    done | sort -u
)

POWER=$'󰌾  Lock\n󰍃  Logout\n󰒲  Suspend\n󰜉  Reboot\n󰐥  Shutdown (poweroff)'

menu() {
    wofi --dmenu --exec-search --matching contains --prompt "" \
        --width 480 --height 380 --cache-file /dev/null
}

calc_loop() {
    local expr="$1" history="" result
    while true; do
        result=$(qalc -t "$expr" 2>&1 | tail -n1)
        history="= $result"$'\n'"$history"
        expr=$(printf '%s' "$history" | menu) || exit 0
        [ -z "$expr" ] && exit 0
        if [[ "$expr" == "= "* ]]; then
            printf '%s' "${expr#= }" | wl-copy
            exit 0
        fi
    done
}

list="$POWER"$'\n'"$(printf '%s\n' "${!APPS[@]}" | sort)"
input=$(printf '%s\n' "$list" | menu) || exit 0
[ -z "$input" ] && exit 0

case "$input" in
    *Lock)       hyprlock; exit ;;
    *Logout)     hyprctl dispatch exit; exit ;;
    *Suspend)    systemctl suspend; exit ;;
    *Reboot)     systemctl reboot; exit ;;
    *Shutdown*)  systemctl poweroff; exit ;;
esac

# an app from the list
if [ -n "${APPS[$input]}" ]; then
    setsid gtk-launch "${APPS[$input]}" >/dev/null 2>&1 &
    exit
fi

# contains a digit -> calculator
if [[ "$input" =~ [0-9] ]]; then
    calc_loop "$input"
fi

# a real command (e.g. "kitty", "firefox")
if command -v "${input%% *}" >/dev/null 2>&1; then
    setsid bash -c "$input" >/dev/null 2>&1 &
    exit
fi

# anything else (pi, e, sqrt(2)...) -> calculator
calc_loop "$input"