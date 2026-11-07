# WoW Docker

Run Battle.net and World of Warcraft in a Linux container. Wine stays inside the container.
Your Battle.net installation, settings and game downloads are saved between launches.

## Requirements

- An x86-64 Linux desktop with Docker Engine, Git, Bash, GNU coreutils and `flock`.
- Permission to use Docker as your normal user.
- X11, or a Wayland desktop with XWayland available.
- A Vulkan-capable NVIDIA, AMD or Intel GPU with working host drivers.
- Desktop audio through PulseAudio or PipeWire's PulseAudio support.

NVIDIA also requires NVIDIA Container Toolkit configured for Docker.
AMD and Intel require access to the GPU's `/dev/dri` devices.

## Install

For a new installation:

```sh
git clone https://github.com/St4NNi/wow-docker.git
cd wow-docker
docker pull ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
./scripts/install.sh --image ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c --display x11
```

This adds **WoW Docker** to your applications menu and installs the `wow-docker` command in `~/.local/bin`.
The image is public, so pulling it does not require signing in. The installer does not need sudo.

The example uses X11/XWayland because native Wayland currently has a WoW startup issue on the tested NVIDIA system.
See [Troubleshooting](#troubleshooting).

Run `./scripts/install.sh --help` to choose custom program, menu, settings or game-data paths.
Use `--no-desktop` if you only want the command.
For an existing installation, follow [Update the image](#update-the-image).

## Play

Open **WoW Docker** from the applications menu, or run:

```sh
wow-docker
```

If your shell cannot find the command, use `~/.local/bin/wow-docker`.

The first launch creates the Wine environment and installs Battle.net automatically.
A progress window may appear. Sign in to Battle.net, choose your WoW version and install the game.
Later launches reuse the same installation.

Exit Battle.net and its games before starting another session. Closing Battle.net's window may leave it running in the background.

## Settings

Edit the existing assignments in `~/.config/wow-docker/config` to change your settings.
If you selected another file with `--config-file`, edit that file instead.
The menu entry and command use the same settings. Changes apply on the next launch.

| Setting | Use |
| --- | --- |
| `WOW_DOCKER_IMAGE` | Docker image to run |
| `WOW_DOCKER_DATA_DIR` | Installation and game-data directory; normally `~/.local/share/wow-docker` |
| `WOW_DOCKER_DISPLAY` | `x11`, `wayland` or `auto` |
| `WOW_DOCKER_GPU` | `auto`, `nvidia`, `amd`, `intel` or `mesa` |
| `WOW_DOCKER_LOCALE` | Keyboard/input locale, such as `de_DE.UTF-8` |
| `WOW_DOCKER_LANGUAGE` | Interface language, such as `en-US` or `de-DE` |
| `WOW_DOCKER_MEMORY` | Container memory limit; normally `12g` |
| `WOW_DOCKER_CPUS` | Container CPU limit; leave empty to use up to eight host CPUs |

For a German keyboard and an English interface:

```sh
WOW_DOCKER_LOCALE=de_DE.UTF-8
WOW_DOCKER_LANGUAGE=en-US
```

Your desktop's physical keyboard layout should also be German.
WoW's text and audio language are separate settings in Battle.net.
New installations can use `--locale de_DE.UTF-8 --language en-US` with the installer.

To try a setting for one launch:

```sh
WOW_DOCKER_DISPLAY=x11 wow-docker
```

Settings passed this way take precedence over the settings file.
Changing `WOW_DOCKER_DATA_DIR` selects a separate installation; it does not move existing game files.

## Update the image

Pull the new fixed image tag, then change `WOW_DOCKER_IMAGE` in your settings file to match.
For example, to select the published image used above:

```sh
docker pull ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
```

Set this value in the settings file:

```sh
WOW_DOCKER_IMAGE=ghcr.io/st4nni/wow-docker:sha-a8e3d53eca908a4dd536a1e383c2a82a1efa875c
```

The launcher uses the selected local image and never pulls updates automatically.

## Troubleshooting

**WoW shows only a taskbar icon under native Wayland.**
This occurs with Wine 11.21 on the tested NVIDIA system. X11/XWayland opens the game.
Set `WOW_DOCKER_DISPLAY=x11` in your settings file, then fully exit and reopen WoW Docker.
This also works from a Wayland desktop.

**Another session is already running.**
Exit Battle.net from its menu, including any background/tray instance, and close its games before launching again.

To see launcher diagnostics, run:

```sh
wow-docker battlenet launch --verbose
```

After exiting Battle.net, check graphics, audio and Wine with:

```sh
wow-docker check
```

## Uninstall

From the repository directory, run:

```sh
./scripts/install.sh --uninstall
```

For custom paths, pass the same `--bin-dir` and `--applications-dir` options used during installation.
This removes the command and menu entry. It keeps your settings, Battle.net installation, game files and Docker images.
It does not stop a running session.

## Build locally

As an alternative to pulling an image, install Docker Buildx, `nice` and `ionice`, then run:

```sh
./scripts/build.sh
./scripts/install.sh --display x11
```

Docker must support memory and CPU limits. The build uses up to four CPU cores and 4 GiB of memory.

## License

The project files use the [MIT License](LICENSE). Bundled software keeps its own licenses.
Battle.net and World of Warcraft are proprietary Blizzard Entertainment software, downloaded separately.
This project is not affiliated with Blizzard Entertainment.
