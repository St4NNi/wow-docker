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
./scripts/install.sh --no-desktop
```

Playing locally requires an X11 or Wayland session and a Vulkan-capable GPU.
The image uses Arch's Wine staging build in WoW64 mode.
It includes both Windows DLL architectures without requiring 32-bit host Wine packages.

## Build and check

```sh
./scripts/build.sh
./scripts/run.sh check
```

The build uses a temporary builder capped at four CPU cores and 4 GiB of memory.
The builder and its cache are removed when the build finishes.
The check verifies Vulkan, connection to desktop audio, and 64-bit and 32-bit Windows commands.

## Install the application entry

```sh
./scripts/install.sh
```

This installs `wow-docker.sh` with a `wow-docker` command alias in `~/.local/bin` and adds **WoW Docker** to the applications menu.
It builds the image if it is missing. No sudo is needed for this user-local installation.
The installed launcher is a copy and does not depend on the repository staying in its current location.

Paths and initial settings can be selected without prompts:

```sh
./scripts/install.sh --bin-dir "$HOME/.local/bin" \
  --applications-dir "$HOME/.local/share/applications" \
  --config-file "$HOME/.config/wow-docker/config" \
  --data-dir "$HOME/Games/wow-docker" \
  --display auto --gpu auto --memory 12g
```

Run `./scripts/install.sh --help` for all options. The installer preserves an existing settings file.
Edit that file to change an existing installation's settings, or select another `--config-file`.
Changing the data path selects a different Wine environment; the installer does not move game files.
Only launchers and menu entries created by this installer are replaced on later installs.
A custom applications directory must be in your desktop's application search path.

## Uninstall

```sh
./scripts/install.sh --uninstall
```

For custom installation paths, pass the same `--bin-dir` and `--applications-dir` options.
This removes the installed command, its alias and the menu entry. It keeps the settings file,
Wine environment, Battle.net, game downloads and Docker images. It does not stop a running session.

## Use a prebuilt image

The public image is available at `ghcr.io/st4nni/wow-docker` without signing in.
These commands use a published commit tag. Pull it first, then install with that image name.
The installer then skips the local build:

```sh
docker pull ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
./scripts/install.sh --image ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
wow-docker
```

For an existing installation, pull the image and edit the `WOW_DOCKER_IMAGE` assignment
in the settings file instead:

```sh
WOW_DOCKER_IMAGE=ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
```

To update, pull the new commit tag and change `WOW_DOCKER_IMAGE` to match.
The launcher never pulls images.

## Install and play

```sh
./scripts/run.sh
```

The first launch creates the Wine environment and installs Battle.net automatically.
Setup uses English by default and the standard install path. `WOW_DOCKER_LANGUAGE` selects another language.
A progress window may appear, but no installer choices are needed.
Later launches reuse the installation. Battle.net account sign-in remains in the client.
Select WoW: Forever there to install the game.
Close Battle.net and its games before starting another session.

## Configuration

Settings are stored in `~/.config/wow-docker/config`, or the file selected with `--config-file`.
This is a Bash file containing defaults for the variables below. Edit the assignment values to change settings.
The generated guards preserve environment overrides. The menu entry and installed command use the same file.
The repository's `scripts/run.sh` and `scripts/build.sh` scripts also read the standard settings file.
Set `WOW_DOCKER_CONFIG` to use another file with those scripts.

These environment variables can also be set when running the scripts:

| Variable | Default | Purpose |
| --- | --- | --- |
| `WOW_DOCKER_CONFIG` | `$XDG_CONFIG_HOME/wow-docker/config` or `~/.config/wow-docker/config` | Host settings file |
| `WOW_DOCKER_IMAGE` | `wow-docker:local` | Local image name |
| `WOW_DOCKER_DATA_DIR` | `$XDG_DATA_HOME/wow-docker` or `~/.local/share/wow-docker` | Persistent container home |
| `WOW_DOCKER_GPU` | `auto` | `nvidia`, `amd`, `intel` or the shared `mesa` backend |
| `WOW_DOCKER_DISPLAY` | `auto` | Detect Wayland/X11, or force `wayland` or `x11` |
| `WOW_DOCKER_LOCALE` | Host `LANG`, or `en_US.UTF-8` | Wine input locale and initial keyboard layout |
| `WOW_DOCKER_LANGUAGE` | Application defaults | Wine and Battle.net interface language, such as `en-US` or `de-DE` |
| `WOW_DOCKER_MEMORY` | `12g` | Container memory limit |
| `WOW_DOCKER_CPUS` | Up to `8` host CPUs | Container CPU limit |
| `WOW_DOCKER_CONTAINER` | `wow-docker-<uid>` | Name for the running container |

For a German keyboard with an English interface, set these values in the settings file:

```sh
WOW_DOCKER_LOCALE=de_DE.UTF-8
WOW_DOCKER_LANGUAGE=en-US
```

The desktop supplies the physical keyboard layout. The Wine locale supplies its initial Windows layout;
the interface language is independent. The image includes the available UTF-8 locales.
New installations also accept `./scripts/install.sh --locale de_DE.UTF-8 --language en-US`.
Changes take effect on the next launch. WoW text and audio language remain per-game settings in Battle.net.

Display selection uses the current session. AMD and Intel use the host DRM render devices and do not need NVIDIA tooling.
For example, select AMD rendering with X11/XWayland:

```sh
WOW_DOCKER_DISPLAY=x11 WOW_DOCKER_GPU=amd ./scripts/run.sh
```

On mixed-GPU X11 sessions with an active NVIDIA display, Mesa uses CPU-copy presentation to avoid a driver crash.
Rendering still uses the selected GPU. Wayland keeps the direct rendering path.
An explicit `MESA_VK_WSI_DEBUG` value overrides this compatibility setting.

Rootless Docker uses container UID 0, which maps to the host user. GPU device permissions and cgroup delegation
must be configured for that daemon. Rootful user-namespace remapping is disabled for this container so desktop UID access works.
On SELinux Docker hosts, labeling is disabled for this container to permit the desktop sockets; host labels are not changed.

`./scripts/run.sh shell` opens a container shell. `./scripts/run.sh wine winecfg` opens Wine configuration.
Wine and graphics debug variables can be passed through the environment.

For visible launch diagnostics, run this in a terminal:

```sh
wow-docker battlenet launch --verbose
```

The application-menu entry does not open a terminal. Native Wayland uses software compositing for
Battle.net's Chromium UI as a compatibility mode. Games keep their GPU rendering.

On the tested NVIDIA system, Wine 11.21's native Wayland driver can leave WoW running with only a taskbar icon
and no game window. The X11/XWayland comparison opens the game. Until that startup issue is resolved, use:

```sh
WOW_DOCKER_DISPLAY=x11 wow-docker
```

Set `WOW_DOCKER_DISPLAY=x11` in the settings file to use that mode from the applications menu too.

## Structure

- `Containerfile`: versioned Arch and Go images pinned by digest, a dated Arch package snapshot,
  Wine, DXVK and VKD3D-Proton. The `wine` target provides the general runtime;
  `battlenet` adds the pinned [bnetctl](https://github.com/bnema/bnetctl) helper.
  Its unattended setup and display compatibility changes are applied inside the build.
- `scripts/entrypoint.sh`: container startup and runtime checks.
- `scripts/battlenet.sh`: Battle.net commands inside the image.
- `scripts/install.sh`: user-local installation and removal.
- `scripts/build.sh`: resource-limited local image build with a versioned BuildKit image pinned by digest.
- `scripts/run.sh`: host GPU, display, audio and storage connections.
- `.github/workflows/image.yml`: script checks, image build, image test and publishing.

The runtime uses Arch `base-20261101.0.620205`, the `2026/11/06` package snapshot and Wine `11.21-1`.
The helper builds with Go `1.27.3` on Alpine `3.24`. Local builds and CI use BuildKit `0.34.2`.
Update explicit image tags and digests together. Package and component versions are Containerfile build arguments,
for example `./scripts/build.sh --build-arg ARCH_DATE=YYYY/MM/DD`.
Keep the Wine version, archive date and graphics component versions consistent.

The container runs as your user ID with dropped capabilities and a read-only root filesystem.
It mounts its own data directory and the required graphics and audio connections.
Its kernel and GPU driver are shared with the host.
The X11 option grants the application access to that X server.

Runtime data is excluded from the build context. Never add Battle.net account data or game files to Git.
The image contains the helper's license. Blizzard software is downloaded separately when you install it.

## Continuous integration and publishing

The workflow runs on `ubuntu-26.04`. It checks the shell scripts with ShellCheck and the workflow with actionlint.
It then builds a `linux/amd64` image from `Containerfile` with the same 4 CPU and 4 GiB caps as `./scripts/build.sh`.
A headless test runs 64-bit and 32-bit Windows commands, checks the DXVK, VKD3D-Proton and helper files,
and runs the helper's help command without network access.
The runners have no GPU, display or audio, so `./scripts/run.sh check` and games are not tested there.
CI never signs in to Battle.net and never downloads Blizzard software.

| Trigger | Result | Image tags |
| --- | --- | --- |
| Pull request | Build and test, no registry login | None |
| Push to `main` | Build, test, publish | `main`, `sha-<commit>` |
| Push of a tag such as `v1.2.3` | Build, test, publish | `1.2.3`, `1.2`, `sha-<commit>` |
| Manual run on a branch | Build, test, publish | Branch name, `sha-<commit>` |

Publishing uses the workflow's `GITHUB_TOKEN` with `contents: read` and `packages: write`. No other secret is needed.
The exact tested image is pushed after its test passes, without a second build. To set it up:

1. Push the repository to GitHub with `main` as the default branch, and keep GitHub Actions enabled.
2. Push to `main`, push a version tag, or start **Container image** from the Actions tab.
3. If the package is private, make it public in its package settings to allow pulls without login.
   If a package with that name already exists, give this repository's Actions write access to it there.

[GitHub Actions runs](https://github.com/St4NNi/wow-docker/actions/workflows/image.yml)
show the build, test and publishing results for each revision.

## License

The project's own files (scripts, `Containerfile`, the workflow and this documentation)
are licensed under the MIT License. See `LICENSE`.

The image also contains third-party software under its own licenses. The project license does not cover it:

- Wine staging from Arch Linux: LGPL-2.1-or-later.
- [DXVK](https://github.com/doitsujin/dxvk): zlib license.
- [VKD3D-Proton](https://github.com/HansKristian-Work/vkd3d-proton): GNU LGPL 2.1.
- Mesa, Vulkan and the other Arch Linux packages: their own licenses, shown by `pacman -Qi` in the image.
- [bnetctl](https://github.com/bnema/bnetctl): MIT License, shipped as `/usr/share/licenses/bnetctl/LICENSE`.
  `Containerfile` applies the project's changes during the build.

Battle.net and World of Warcraft are proprietary Blizzard Entertainment software under Blizzard's own terms.
They are not part of this project or the image. This project is not affiliated with Blizzard Entertainment.
