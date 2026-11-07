#!/usr/bin/env bash
set -euo pipefail

# Battle.net uses Chromium and does not need Wine Mono or Gecko.
export WINEDLLOVERRIDES="mscoree,mshtml=;${WINEDLLOVERRIDES:-}"

if (( $# == 0 )); then
    set -- launch
fi
case "$1" in
    install|launch)
        exec bnetctl "$@" --display-driver "${WINE_DISPLAY_DRIVER:-wayland}"
        ;;
    *) exec bnetctl "$@" ;;
esac
