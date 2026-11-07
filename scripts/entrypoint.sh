#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
if [[ -n ${WOW_DOCKER_LANGUAGE:-} && ( ${1:-} == wine || ${1:-} == check ) ]]; then
    WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;${WINEDLLOVERRIDES:-}" wine reg add \
        'HKCU\Control Panel\Desktop' /v PreferredUILanguages /t REG_MULTI_SZ \
        /d "$WOW_DOCKER_LANGUAGE" /f >/dev/null
fi
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
