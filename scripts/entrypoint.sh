#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
if [[ "${1:-}" == check ]]; then
    wine --version
    vulkaninfo --summary
    pactl info | sed -n '/Server Name:/p; /Default Sink:/p'
    WINEDLLOVERRIDES='mscoree,mshtml=' WINEDEBUG=-all wine 'C:\\windows\\system32\\cmd.exe' /c ver
    WINEDLLOVERRIDES='mscoree,mshtml=' WINEDEBUG=-all wine 'C:\\windows\\syswow64\\cmd.exe' /c ver
    wineserver -w
    exit
fi
exec "$@"
