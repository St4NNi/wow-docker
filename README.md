# WoW Docker

Run Battle.net and World of Warcraft in a dedicated Linux container.
Wine stays inside the image. Game files and settings stay in a separate directory.

## Requirements

- Linux x86-64 with Docker Engine, Buildx, Bash, flock, nice and ionice.
- A working Wayland desktop, or X11 with an authority file.
- Desktop audio through PulseAudio or PipeWire's PulseAudio socket.
- NVIDIA: install NVIDIA Container Toolkit and check that `nvidia-ctk cdi list` shows a GPU.
  Docker must support native CDI, enabled by default since Engine 28.3.
- AMD or Intel: working host graphics drivers and access to `/dev/dri`.

The image uses Arch's Wine staging build in WoW64 mode.
It includes both Windows DLL architectures without requiring 32-bit host Wine packages.

## Build and check

```sh
./build
./run check
```

The build uses a temporary builder capped at four CPU cores and 4 GiB of memory.
The builder and its cache are removed when the build finishes.
The check verifies Vulkan, connection to desktop audio, and 64-bit and 32-bit Windows commands.

## Install and play

```sh
./run
```

The first launch creates the Wine environment and installs Battle.net automatically.
Setup uses English and the default install path. A progress window may appear, but no installer choices are needed.
Later launches reuse the installation. Battle.net account sign-in remains in the client.
Select WoW: Forever there to install the game.
Close Battle.net and its games before starting another session.

## Configuration

Set these environment variables when running the scripts:

| Variable | Default | Purpose |
| --- | --- | --- |
| `WOW_DOCKER_IMAGE` | `wow-docker:local` | Local image name |
| `WOW_DOCKER_DATA_DIR` | `$XDG_DATA_HOME/wow-docker` or `~/.local/share/wow-docker` | Persistent container home |
| `WOW_DOCKER_GPU` | `auto` | `nvidia` or `mesa` |
| `WOW_DOCKER_DISPLAY` | `wayland` | `wayland` or `x11` |
| `WOW_DOCKER_MEMORY` | `12g` | Container memory limit |
| `WOW_DOCKER_CPUS` | Up to `8` host CPUs | Container CPU limit |
| `WOW_DOCKER_CONTAINER` | `wow-docker-<uid>` | Name for the running container |

For example, use XWayland for a launcher that has native Wayland problems:

```sh
WOW_DOCKER_DISPLAY=x11 ./run battlenet launch
```

`./run shell` opens a container shell. `./run wine winecfg` opens Wine configuration.
Wine and graphics debug variables can be passed through the environment.

## Structure

- `Containerfile`: pinned Arch snapshot, Wine, DXVK and VKD3D-Proton.
  The `wine` target provides the general runtime; `battlenet` adds the launcher helper.
- `container/entrypoint`: container startup and runtime checks.
- `profiles/battlenet`: Battle.net commands through the pinned
  [bnetctl](https://github.com/bnema/bnetctl) helper.
- `container/battlenet.patch`: unattended setup arguments and first-launch installation for the pinned helper.
- `build`: resource-limited local image build.
- `run`: host GPU, display, audio and storage connections.

Change versions through Containerfile build arguments, for example `./build --build-arg ARCH_DATE=YYYY/MM/DD`.
Keep the Wine version, archive date and graphics component versions consistent.

The container runs as your user ID with dropped capabilities and a read-only root filesystem.
It mounts its own data directory and the required graphics and audio connections.
Its kernel and GPU driver are shared with the host.
The X11 option grants the application access to that X server.

Runtime data is excluded from the build context. Never add Battle.net account data or game files to Git.
The image contains the helper's license. Blizzard software is downloaded separately when you install it.
