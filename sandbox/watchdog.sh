#!/usr/bin/env bash
# Build watchdog, run on the Windows side (Git Bash) next to a build in the WSL sandbox.
# It never touches the build; it only watches and reports, one line per event:
#   WATCHDOG: WSL not responding for N min        the sandbox hangs (it froze twice before)
#   WATCHDOG: no build output for N min ...        the build may be stuck
#   WATCHDOG: Windows has only N MB RAM free       memory pressure, a freeze may follow
#   WATCHDOG: build finished: <last result line>   the build job ended
# Usage: sandbox/watchdog.sh UNIT LOG [STALL_MINUTES]
#   UNIT  systemd user unit the build runs in (e.g. klive, kbuild)
#   LOG   build log inside WSL (e.g. /home/<user>/live-iso.log)
set -uo pipefail
unit=${1:?unit} log=${2:?log} stall_min=${3:-25}
distro=FedoraLinux-44
export MSYS_NO_PATHCONV=1

unresponsive=0 last_stall_report=0 last_ram_report=0
while true; do
    # One short query; if WSL hangs, timeout gives up instead of hanging the watchdog.
    out=$(timeout 60 wsl.exe -d "$distro" -- bash -c "
        echo active=\$(systemctl --user is-active $unit)
        echo age=\$(( \$(date +%s) - \$(stat -c %Y $log 2>/dev/null || date +%s) ))
        echo last=\$(tail -c 300 $log 2>/dev/null | tr '\r' '\n' | grep -v '^\s*\$' | tail -1 | cut -c1-120)
    " 2>/dev/null | tr -d '\0')
    if ! grep -q '^active=' <<<"$out"; then
        unresponsive=$((unresponsive + 1))
        (( unresponsive % 5 == 0 )) && echo "WATCHDOG: WSL not responding for $unresponsive min"
    else
        (( unresponsive >= 5 )) && echo "WATCHDOG: WSL responds again after $unresponsive min"
        unresponsive=0
        active=$(sed -n 's/^active=//p' <<<"$out")
        age=$(sed -n 's/^age=//p' <<<"$out")
        last=$(sed -n 's/^last=//p' <<<"$out")
        if [[ $active != active && $active != activating ]]; then
            echo "WATCHDOG: build finished: $last"
            exit 0
        fi
        if (( age > stall_min * 60 && SECONDS - last_stall_report > 600 )); then
            echo "WATCHDOG: no build output for $(( age / 60 )) min, last line: $last"
            last_stall_report=$SECONDS
        fi
    fi
    free_mb=$(powershell.exe -NoProfile -Command \
        '[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1KB)' 2>/dev/null | tr -dc '0-9')
    if [[ -n $free_mb ]] && (( free_mb < 400 && SECONDS - last_ram_report > 600 )); then
        echo "WATCHDOG: Windows has only $free_mb MB RAM free"
        last_ram_report=$SECONDS
    fi
    sleep 60
done
