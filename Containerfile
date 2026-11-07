ARG BASE_IMAGE=archlinux:base@sha256:b1c2fe6e717bfd5673af8fc217e1e1c3ce0dcbb1d53c3414c8425e7ce79fc6d9
FROM ${BASE_IMAGE} AS wine
ARG ARCH_DATE=2026/11/06
ARG WINE_VERSION=11.21-1
ARG DXVK_VERSION=3.1.1
ARG DXVK_SHA256=40565b4a724aadc4433fa4e010b4b23916d9b1f1baeee64e17186db94f54e608
ARG VKD3D_VERSION=3.1
ARG VKD3D_SHA256=b85ea8219b71093a3924913dd7aae6172333dc0c069983ed510816d67f02120b
# The host supplies the kernel and optional ntsync device.
RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_DATE" > /etc/pacman.d/mirrorlist \
    && pacman -Syu --noconfirm --needed --assume-installed ntsync-autoload wine-staging curl cabextract unzip gnutls \
       libpulse alsa-plugins vulkan-icd-loader vulkan-tools mesa vulkan-radeon \
       vulkan-intel ttf-dejavu ttf-liberation dbus \
    && test "$(pacman -Q wine-staging)" = "wine-staging $WINE_VERSION" \
    && printf 'y\ny\n' | pacman -Scc \
    && useradd --create-home --uid 1000 player
ADD --checksum=sha256:${DXVK_SHA256} https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz /opt/dxvk.tar.gz
ADD --checksum=sha256:${VKD3D_SHA256} https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v${VKD3D_VERSION}/vkd3d-proton-${VKD3D_VERSION}.tar.zst /opt/vkd3d.tar.zst
RUN mkdir -p /usr/share/dxvk /usr/share/vkd3d-proton \
    && tar -xf /opt/dxvk.tar.gz -C /usr/share/dxvk --strip-components=1 \
    && tar -xf /opt/vkd3d.tar.zst -C /usr/share/vkd3d-proton --strip-components=1 \
    && rm /opt/dxvk.tar.gz /opt/vkd3d.tar.zst
ENV HOME=/home/player \
    USER=player \
    XDG_DATA_HOME=/home/player/.local/share \
    XDG_CACHE_HOME=/home/player/.cache \
    WINEPREFIX=/home/player/prefix
COPY LICENSE /usr/share/licenses/wow-docker/LICENSE
COPY --chmod=755 container/entrypoint /usr/local/bin/container-entrypoint
USER 1000:1000
WORKDIR /home/player
ENTRYPOINT ["container-entrypoint"]
CMD ["wine", "winecfg"]

FROM golang:1.26-alpine@sha256:87c65a688975c0b1d4585d204874c45ca78354670e3a5f11368c5a492303d696 AS helper
ARG BNETCTL_COMMIT=c542b0efa2625f56b6e8302b193bf726a4a4b509
ADD https://codeload.github.com/bnema/bnetctl/tar.gz/${BNETCTL_COMMIT} /source.tar.gz
RUN mkdir /source && tar -xf /source.tar.gz -C /source --strip-components=1
WORKDIR /source
COPY container/battlenet.patch /battlenet.patch
RUN apk add --no-cache patch && patch -p1 < /battlenet.patch && gofmt -w cmd/install.go cmd/launch.go internal/adapters/env/gpu.go
RUN CGO_ENABLED=0 GOMAXPROCS=2 go build -p 2 -trimpath -ldflags="-s -w -X github.com/bnema/bnetctl/cmd.commit=$BNETCTL_COMMIT" -o /bnetctl .

FROM wine AS battlenet
COPY --from=helper /bnetctl /usr/local/bin/bnetctl
COPY --from=helper /source/LICENSE /usr/share/licenses/bnetctl/LICENSE
COPY --chmod=755 profiles/battlenet /usr/local/bin/battlenet
CMD ["battlenet", "launch"]
