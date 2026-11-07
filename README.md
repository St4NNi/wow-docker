# WoW Docker

Run Battle.net and World of Warcraft in a dedicated Linux container.
Wine stays inside the image. Game files and settings stay in a separate directory.

## Requirements

- Linux x86-64 with a local Docker Engine, Bash, GNU coreutils, flock, nice and ionice.
  Buildx and working memory/CPU controls are needed when building a missing image.
- A working Wayland desktop, or X11 with an authority file.
- Desktop audio through PulseAudio or PipeWire's PulseAudio socket.
- NVIDIA: install and configure NVIDIA Container Toolkit. The launcher uses native CDI when NVIDIA devices are discovered,
  and otherwise uses the NVIDIA runtime through `--gpus all`.
- AMD or Intel: working host graphics drivers and access to `/dev/dri`.

The installer does not depend on a distribution package manager or a particular init system.
It targets x86-64 Linux distributions, including systemd desktops such as Arch, Debian, Ubuntu, Fedora and openSUSE.
Docker and the host graphics drivers must already work. Installation can also run without a desktop:

```sh
./install --no-desktop
```

Playing locally requires an X11 or Wayland session and a Vulkan-capable GPU.
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

## Install the application entry

```sh
./install
```

This installs the `wow-docker` command in `~/.local/bin` and adds **WoW Docker** to the applications menu.
It builds the image if it is missing. No sudo is needed for this user-local installation.
The installed launcher is a copy and does not depend on the repository staying in its current location.

Paths and initial settings can be selected without prompts:

```sh
./install --bin-dir "$HOME/.local/bin" \
  --applications-dir "$HOME/.local/share/applications" \
  --config-file "$HOME/.config/wow-docker/config" \
  --data-dir "$HOME/Games/wow-docker" \
  --display auto --gpu auto --memory 12g
```

Run `./install --help` for all options. The installer preserves an existing settings file.
Edit that file to change an existing installation's settings, or select another `--config-file`.
Changing the data path selects a different Wine environment; the installer does not move game files.
Only launchers and menu entries created by this installer are replaced on later installs.
A custom applications directory must be in your desktop's application search path.

## Use a prebuilt image

The GitHub workflow publishes the image as `ghcr.io/<owner>/<repository>`, the lowercase GitHub repository path.
Replace `<owner>` and `<repository>` with the GitHub repository path.
Pull it first, then install with that image name. The installer then skips the local build:

```sh
docker pull 'ghcr.io/<owner>/<repository>:latest'
./install --image 'ghcr.io/<owner>/<repository>:latest'
```

For an existing installation, set `WOW_DOCKER_IMAGE` in the settings file instead.
The launcher never pulls images, so run `docker pull` again to update.
A private package needs `docker login ghcr.io` before the pull.

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

Settings are stored in `~/.config/wow-docker/config`, or the file selected with `--config-file`.
This is a Bash file containing defaults for the variables below. Edit the assignment values to change settings.
The generated guards preserve environment overrides. The menu entry and installed command use the same file.
The repository's `run` and `build` scripts also read the standard settings file.
Set `WOW_DOCKER_CONFIG` to use another file with those scripts.

These environment variables can also be set when running the scripts:

| Variable | Default | Purpose |
| --- | --- | --- |
| `WOW_DOCKER_CONFIG` | `$XDG_CONFIG_HOME/wow-docker/config` or `~/.config/wow-docker/config` | Host settings file |
| `WOW_DOCKER_IMAGE` | `wow-docker:local` | Local image name |
| `WOW_DOCKER_DATA_DIR` | `$XDG_DATA_HOME/wow-docker` or `~/.local/share/wow-docker` | Persistent container home |
| `WOW_DOCKER_GPU` | `auto` | `nvidia`, `amd`, `intel` or the shared `mesa` backend |
| `WOW_DOCKER_DISPLAY` | `auto` | Detect Wayland/X11, or force `wayland` or `x11` |
| `WOW_DOCKER_MEMORY` | `12g` | Container memory limit |
| `WOW_DOCKER_CPUS` | Up to `8` host CPUs | Container CPU limit |
| `WOW_DOCKER_CONTAINER` | `wow-docker-<uid>` | Name for the running container |

Display selection uses the current session. AMD and Intel use the host DRM render devices and do not need NVIDIA tooling.
For example, select AMD rendering with X11/XWayland:

```sh
WOW_DOCKER_DISPLAY=x11 WOW_DOCKER_GPU=amd ./run
```

On mixed-GPU X11 sessions with an active NVIDIA display, Mesa uses CPU-copy presentation to avoid a driver crash.
Rendering still uses the selected GPU. Wayland keeps the direct rendering path.
An explicit `MESA_VK_WSI_DEBUG` value overrides this compatibility setting.

Rootless Docker uses container UID 0, which maps to the host user. GPU device permissions and cgroup delegation
must be configured for that daemon. Rootful user-namespace remapping is disabled for this container so desktop UID access works.
On SELinux Docker hosts, labeling is disabled for this container to permit the desktop sockets; host labels are not changed.

`./run shell` opens a container shell. `./run wine winecfg` opens Wine configuration.
Wine and graphics debug variables can be passed through the environment.

For visible launch diagnostics, run this in a terminal:

```sh
wow-docker battlenet launch --verbose
```

The application-menu entry does not open a terminal. Native Wayland uses software compositing for
Battle.net's Chromium UI as a compatibility mode. Games keep their GPU rendering.

## Structure

- `Containerfile`: pinned Arch snapshot, Wine, DXVK and VKD3D-Proton.
  The `wine` target provides the general runtime; `battlenet` adds the launcher helper.
- `container/entrypoint`: container startup and runtime checks.
- `profiles/battlenet`: Battle.net commands through the pinned
  [bnetctl](https://github.com/bnema/bnetctl) helper.
- `container/battlenet.patch`: unattended setup, first-launch installation and visible-GPU detection for the pinned helper.
- `install`: user-local command, settings and desktop entry installation.
- `build`: resource-limited local image build.
- `run`: host GPU, display, audio and storage connections.
- `.github/workflows/image.yml`: script checks, image build, image test and publishing.

Change versions through Containerfile build arguments, for example `./build --build-arg ARCH_DATE=YYYY/MM/DD`.
Keep the Wine version, archive date and graphics component versions consistent.

The container runs as your user ID with dropped capabilities and a read-only root filesystem.
It mounts its own data directory and the required graphics and audio connections.
Its kernel and GPU driver are shared with the host.
The X11 option grants the application access to that X server.

Runtime data is excluded from the build context. Never add Battle.net account data or game files to Git.
The image contains the helper's license. Blizzard software is downloaded separately when you install it.

## Continuous integration and publishing

The workflow checks the shell scripts with ShellCheck and the workflow with actionlint.
It then builds a `linux/amd64` image from `Containerfile` with the same 4 CPU and 4 GiB caps as `./build`.
A headless test runs 64-bit and 32-bit Windows commands, checks the DXVK, VKD3D-Proton and helper files,
and runs the helper's help command without network access.
The runners have no GPU, display or audio, so `./run check` and games are not tested there.
CI never signs in to Battle.net and never downloads Blizzard software.

| Trigger | Result | Image tags |
| --- | --- | --- |
| Pull request | Build and test, no registry login | None |
| Push to `main` | Build, test, publish | `latest`, `main`, `sha-<commit>` |
| Push of a tag such as `v1.2.3` | Build, test, publish | `1.2.3`, `1.2`, `sha-<commit>` |
| Manual run on a branch | Build, test, publish | Branch name, `sha-<commit>`, and `latest` on `main` |

Publishing uses the workflow's `GITHUB_TOKEN` with `contents: read` and `packages: write`. No other secret is needed.
The image is only pushed after its test passes. To set it up:

1. Push the repository to GitHub with `main` as the default branch, and keep GitHub Actions enabled.
2. Push to `main`, push a version tag, or start **Container image** from the Actions tab.
3. If the package is private, make it public in its package settings to allow pulls without login.
   If a package with that name already exists, give this repository's Actions write access to it there.

The workflow has not run on GitHub yet, so remote builds and publishing are not verified.

## License

The project's own files (scripts, `Containerfile`, `container/`, `profiles/`, the workflow and this documentation)
are licensed under the MIT License. See `LICENSE`.

The image also contains third-party software under its own licenses. The project license does not cover it:

- Wine staging from Arch Linux: LGPL-2.1-or-later.
- [DXVK](https://github.com/doitsujin/dxvk): zlib license.
- [VKD3D-Proton](https://github.com/HansKristian-Work/vkd3d-proton): GNU LGPL 2.1.
- Mesa, Vulkan and the other Arch Linux packages: their own licenses, shown by `pacman -Qi` in the image.
- [bnetctl](https://github.com/bnema/bnetctl): MIT License, shipped as `/usr/share/licenses/bnetctl/LICENSE`.
  `container/battlenet.patch` modifies it.

Battle.net and World of Warcraft are proprietary Blizzard Entertainment software under Blizzard's own terms.
They are not part of this project or the image. This project is not affiliated with Blizzard Entertainment.
