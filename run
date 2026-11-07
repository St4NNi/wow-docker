#!/usr/bin/env bash
set -euo pipefail

config_file=${WOW_DOCKER_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/wow-docker/config}
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
fi

image=${WOW_DOCKER_IMAGE:-wow-docker:local}
state_dir=${WOW_DOCKER_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/wow-docker}
host_uid=$(id -u)
host_gid=$(id -g)
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$host_uid}
security_options=$(docker info --format '{{json .SecurityOptions}}')
container_uid=$host_uid
container_gid=$host_gid
if [[ "$security_options" == *name=rootless* ]]; then
    container_uid=0
    container_gid=0
fi
container_runtime="/run/user/$container_uid"
display_driver=${WOW_DOCKER_DISPLAY:-auto}
wayland_socket=${WAYLAND_DISPLAY:-wayland-0}
[[ "$wayland_socket" == /* ]] || wayland_socket="$runtime_dir/$wayland_socket"
if [[ "$display_driver" == auto ]]; then
    if [[ -S "$wayland_socket" && ( -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == wayland ) ]]; then
        display_driver=wayland
    elif [[ -n "${DISPLAY:-}" ]]; then
        display_driver=x11
    else
        printf 'A local Wayland or X11 desktop session is required.\n' >&2
        exit 1
    fi
fi
cpu_limit=$(nproc)
(( cpu_limit <= 8 )) || cpu_limit=8

mkdir -p "$state_dir"
state_dir=$(cd -- "$state_dir" && pwd)
exec 9>"$state_dir/session.lock"
flock -n 9 || { printf 'This data directory already has a running session.\n' >&2; exit 1; }

arguments=(run --rm --init --pull never
    --name "${WOW_DOCKER_CONTAINER:-wow-docker-$host_uid}"
    --user "$container_uid:$container_gid" --cap-drop ALL --security-opt no-new-privileges
    --read-only --memory "${WOW_DOCKER_MEMORY:-12g}" --cpus "${WOW_DOCKER_CPUS:-$cpu_limit}"
    --shm-size 1g --tmpfs "/tmp:rw,mode=1777,size=2g"
    --tmpfs "$container_runtime:rw,mode=700,uid=$container_uid,gid=$container_gid,size=16m"
    --env "XDG_RUNTIME_DIR=$container_runtime"
    --env "WINE_DISPLAY_DRIVER=$display_driver")

bind_path() {
    local source=${1//\"/\"\"}
    local target=$2
    local readonly=${3:-}
    arguments+=(--mount "type=bind,\"source=$source\",target=$target${readonly:+,readonly}")
}
bind_path "$state_dir" /home/player

if [[ "$security_options" == *name=userns* && "$security_options" != *name=rootless* ]]; then
    arguments+=(--userns=host)
fi
if [[ "$security_options" == *name=selinux* ]]; then
    arguments+=(--security-opt label=disable)
fi

gpu=${WOW_DOCKER_GPU:-auto}
if [[ "$gpu" == auto ]]; then
    if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
        gpu=nvidia
    else
        gpu=mesa
    fi
fi
case "$gpu" in
    nvidia)
        cdi_devices=$(docker info --format '{{range .DiscoveredDevices}}{{println .ID}}{{end}}' 2>/dev/null || true)
        if [[ $'\n'"$cdi_devices"$'\n' == *$'\nnvidia.com/gpu=all\n'* ]]; then
            arguments+=(--device nvidia.com/gpu=all)
        else
            arguments+=(--gpus all --env "NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display")
        fi
        arguments+=(--env __NV_PRIME_RENDER_OFFLOAD=1 --env __GLX_VENDOR_LIBRARY_NAME=nvidia
            --env __VK_LAYER_NV_optimus=NVIDIA_only)
        if [[ "$display_driver" == wayland ]]; then
            arguments+=(--env GBM_BACKEND=nvidia-drm)
        fi
        if [[ "$container_uid" == "$host_uid" ]]; then
            for device in /dev/nvidia[0-9]* /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-modeset /dev/dri/renderD*; do
                [[ -c "$device" ]] || continue
                arguments+=(--group-add "$(stat -c %g "$device")")
            done
        fi
        ;;
    mesa|amd|intel)
        # Cross-GPU X11 presentation needs a copy path on NVIDIA displays.
        if [[ "$display_driver" == x11 && ! -v MESA_VK_WSI_DEBUG ]] && command -v nvidia-smi >/dev/null; then
            nvidia_display=$(nvidia-smi --query-gpu=display_active --format=csv,noheader 2>/dev/null || true)
            if [[ "$nvidia_display" == *Enabled* ]]; then
                arguments+=(--env "MESA_VK_WSI_DEBUG=sw,noshm")
            fi
        fi
        render_found=false
        for device in /dev/dri/renderD*; do
            [[ -c "$device" ]] || continue
            vendor=$(cat "/sys/class/drm/${device##*/}/device/vendor")
            case "$gpu:$vendor" in
                mesa:0x1002|mesa:0x8086|amd:0x1002|intel:0x8086)
                    arguments+=(--device "$device")
                    if [[ "$container_uid" == "$host_uid" ]]; then
                        arguments+=(--group-add "$(stat -c %g "$device")")
                    fi
                    render_found=true
                    ;;
            esac
        done
        [[ "$render_found" == true ]] || { printf 'No matching AMD or Intel render device is available.\n' >&2; exit 1; }
        ;;
    *) printf 'Use WOW_DOCKER_GPU=auto, nvidia, amd, intel or mesa.\n' >&2; exit 1 ;;
esac

case "$display_driver" in
    wayland)
        [[ -S "$wayland_socket" ]] || { printf 'Wayland socket is unavailable.\n' >&2; exit 1; }
        arguments+=(--env WAYLAND_DISPLAY=wayland-0)
        bind_path "$wayland_socket" "$container_runtime/wayland-0" readonly
        ;;
    x11)
        : "${DISPLAY:?X11 requires DISPLAY}"
        authority=${XAUTHORITY:-$HOME/.Xauthority}
        [[ -f "$authority" ]] || { printf 'X11 authority file is unavailable.\n' >&2; exit 1; }
        display_number=${DISPLAY##*:}
        display_number=${display_number%%.*}
        arguments+=(--env "DISPLAY=$DISPLAY" --env XAUTHORITY=/run/xauthority
            --hostname "$(uname -n)")
        bind_path "$authority" /run/xauthority readonly
        bind_path "/tmp/.X11-unix/X$display_number" "/tmp/.X11-unix/X$display_number" readonly
        ;;
    *) printf 'Use WOW_DOCKER_DISPLAY=auto, wayland or x11.\n' >&2; exit 1 ;;
esac

[[ -S "$runtime_dir/pulse/native" ]] || { printf 'Desktop audio socket is unavailable.\n' >&2; exit 1; }
arguments+=(--env "PULSE_SERVER=unix:$container_runtime/pulse/native")
bind_path "$runtime_dir/pulse/native" "$container_runtime/pulse/native" readonly
if [[ -e /dev/ntsync ]]; then
    arguments+=(--device /dev/ntsync)
fi
for variable in WINEDEBUG DXVK_HUD DXVK_LOG_LEVEL VKD3D_DEBUG MESA_VK_WSI_DEBUG LANG TZ; do
    if [[ -v "$variable" ]]; then
        arguments+=(--env "$variable=${!variable}")
    fi
done
if [[ -t 0 && -t 1 ]]; then
    arguments+=(-it)
fi
if [[ "${1:-}" == shell ]]; then
    shift
    set -- bash "$@"
fi
exec docker "${arguments[@]}" "$image" "$@"
