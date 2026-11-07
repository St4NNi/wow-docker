#!/usr/bin/env bash
set -euo pipefail

config_file=${WOW_DOCKER_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/wow-docker/config}
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
fi

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
image=${WOW_DOCKER_IMAGE:-wow-docker:local}
if [[ "$(docker info --format '{{.MemoryLimit}} {{.CPUCfsQuota}}')" != 'true true' ]]; then
    printf 'Docker memory and CPU limits are required to build the image.\n' >&2
    exit 1
fi
builder="wow-docker-$UID-$$"
cleanup() {
    docker buildx rm "$builder" >/dev/null
}
docker buildx create --name "$builder" --driver docker-container \
    --driver-opt image=moby/buildkit:v0.34.2@sha256:c5f8862f52499773af85bc07695b2379ef08e8002352b0df2c4864c91d78dabe \
    --driver-opt memory=4g,memory-swap=4g,cpu-quota=400000,cpu-shares=128,restart-policy=no >/dev/null
trap cleanup EXIT
nice -n 19 ionice -c3 docker buildx build --builder "$builder" \
    --pull --load --progress plain --file "$project_dir/Containerfile" --tag "$image" \
    "$@" "$project_dir"
