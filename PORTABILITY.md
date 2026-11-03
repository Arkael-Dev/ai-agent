# Running on non-Android Linux / macOS

The bubble (`ai-agent-bubble.sh`) is Termux-only: it relies on Termux:GUI
(`tgui-bash`, `termux-bubble`) and Termux:API, which do not exist on a desktop
Linux distribution.

`ai-agent-chat.sh` is portable. On the `percobaan` branch it has been changed to:

- shebang `#!/usr/bin/env bash` instead of the hard-coded Termux path
- a platform detector (`PLATFORM` = `termux` / `linux` / `macos` / `other`)
- a portable `timeout` shim (`timeout --foreground` -> `gtimeout` -> no limit)
- distro-aware dependency hints instead of `pkg install`
- a new `--doctor` flag to print platform + dependency status

Everything else (providers, BYOK, streaming, history, `run_bash` tool,
`/confirm` for risky commands) works the same.

## Kompatibilitas distro

| Platform | Chat / agent | Bubble | Catatan |
|---|---|---|---|
| Termux (Android) | ✅ | ✅ | target asli |
| Arch / Manjaro | ✅ | – | `pacman -S curl jq` |
| Debian / Ubuntu / Mint | ✅ | – | `apt install curl jq` |
| Fedora / RHEL | ✅ | – | `dnf install curl jq` |
| openSUSE | ✅ | – | `zypper install curl jq` |
| Alpine | ✅ | – | `apk add bash curl jq` |
| proot-distro / chroot | ✅ | – | terdeteksi sebagai `linux`, ada catatan PRoot |
| macOS | ✅* | – | butuh `brew install bash jq` (*bash ≥ 4) |
| WSL | ✅ | – | sama seperti Linux |

Hal yang sudah dibuat portabel:

- **shebang** `#!/usr/bin/env bash` di semua script dan test
- **bash 3.2 guard** — pesan jelas + cara memperbaiki, bukan error sintaks
- **`readlink -f`** diganti `resolve_path` (GNU-only, BSD/macOS tidak punya)
- **`sed -i`** dideteksi otomatis (`-i` vs `-i ''` untuk BSD/macOS)
- **`timeout`** dengan fallback `gtimeout`, lalu tanpa batas waktu
- **hint dependency** mengikuti package manager yang ada
- **`install.sh`** menaruh launcher di dir PATH milik user (tanpa root)
- **menu `ai`** menyembunyikan bubble/autostart di luar Termux
- **system prompt & tool description** mengikuti host yang terdeteksi

Bottleneck terakhir cuma `jq` dan `curl` — keduanya tersedia di semua distro.

## Requirements

Any of:

- bash >= 4
- curl
- jq
- sed, grep

Debian/Ubuntu:
```
sudo apt install bash curl jq coreutils grep
```

Fedora:
```
sudo dnf install bash curl jq coreutils grep
```

Arch:
```
sudo pacman -S bash curl jq coreutils grep
```

macOS (Homebrew):
```
brew install bash curl jq coreutils
```

## Usage

```
git clone -b percobaan https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x ai-agent-chat.sh
./ai-agent-chat.sh --doctor          # check environment
./ai-agent-chat.sh                   # interactive: pick provider, key, model
./ai-agent-chat.sh --no-menu "hi"    # one-shot
```

Config lives in `~/.config/ai-agent/config` on every platform.
Set `AI_CONFIG_DIR` to override.

## Distributions tested

- Arch Linux ARM (aarch64), inside a `proot-distro` container — full test suite
- The code paths for Debian/Ubuntu, Fedora, openSUSE, Alpine and macOS use the
  same portable logic but have not been run on real hardware yet.

## Notes on containers (proot-distro / chroot)

A container built with `proot-distro` on Android still sees `TERMUX_VERSION`
and the Termux mounts, so a naive check marks it as `termux`. The detector
therefore requires both `TERMUX_VERSION` **and** a `PREFIX` that actually
contains `bash`. `--doctor` also reports the container explicitly:

```
platform : linux (Linux 6.17.0-PRoot-Distro aarch64)
distro   : Arch Linux ARM
note     : running inside a PRoot container
```

## Not available outside Termux

- floating bubble overlay
- clipboard quick actions via `termux-clipboard-*`
- toast / TTS / speech-to-text helpers

They degrade gracefully: the chat keeps working, only those helpers are gone.
