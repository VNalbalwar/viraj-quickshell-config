#!/bin/bash
# hw-watch: one quiet process that tells the shell when a hardware state changes - Caps / Num Lock, power profile, fan.
# It only reads files, using bash built-ins, so it starts NO other programs (the old approach started ~20 per second),
# and it only prints when something changed. Lines:  locks <caps 0|1> <num 0|1>  |  profile <name>  |  fan <left>,<right>
exec 9<> <(:)                        # a pipe nobody writes to: `read -t` on it is a sleep that needs no `sleep` process
FAN="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed"
PROFILE=/sys/firmware/acpi/platform_profile
last_locks= last_profile= last_fan= tick=0
any_on() {                           # sets REPLY=1 if any of the given LED files is lit (every keyboard has its own)
    local f v
    REPLY=0
    for f in "$@"; do v=0; { read -r v < "$f"; } 2>/dev/null; (( v > 0 )) && REPLY=1; done
}
while [[ -d /proc/$PPID ]]; do       # leave when the shell does
    any_on /sys/class/leds/*::capslock/brightness; caps=$REPLY
    any_on /sys/class/leds/*::numlock/brightness
    locks="$caps $REPLY"
    [[ $locks != "$last_locks" ]] && { last_locks=$locks; echo "locks $locks" || exit; }
    if (( tick % 4 == 0 )); then     # once a second is plenty for these
        v=; { read -r v < "$PROFILE"; } 2>/dev/null
        [[ -n $v && $v != "$last_profile" ]] && { last_profile=$v; echo "profile $v" || exit; }
        v=; { read -r v < "$FAN"; } 2>/dev/null
        [[ -n $v && $v != "$last_fan" ]] && { last_fan=$v; echo "fan $v" || exit; }
    fi
    (( tick++ ))
    read -r -t 0.25 -u 9
done
