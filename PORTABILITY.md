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

## Not available outside Termux

- floating bubble overlay
- clipboard quick actions via `termux-clipboard-*`
- toast / TTS / speech-to-text helpers

They degrade gracefully: the chat keeps working, only those helpers are gone.
