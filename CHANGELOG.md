# Changelog

## portable-linux — GUI menu, bubble removed

- `ai-agent` is now the `ai` command: a `dialog`/`whiptail` menu (chat in a new
  terminal window, chat here, AI/key/model, update, close) with a plain-text
  fallback when there is no desktop or `AI_NO_GUI=1`
- terminal emulator detection (gnome-terminal, konsole, xfce4-terminal,
  alacritty, kitty, foot, xterm, …); Terminal.app on macOS
- fixed: the `3>&1 1>&2 2>&3` redirect and multi-line dialog output made the
  chosen menu entry come back empty on some shells
- removed `ai-agent-bubble.sh` and its `pkg install termux-api termux-gui-bash`
  paths (`install.sh` and the install hints no longer mention Termux)
- README / README.id / PORTABILITY.md rewritten for Linux desktops; install
  instructions point at `-b portable-linux` so a plain `git clone` no longer
  pulls the old `main` build

## portable-linux — dukungan Linux / macOS portabel

- `ai-agent-chat.sh`: portable `#!/usr/bin/env bash` shebang
- Platform detection (`termux` / `linux` / `macos` / `other`) that no longer
  misidentifies a proot-distro container as Termux (requires `TERMUX_VERSION`
  *and* a matching `PREFIX`)
- `--doctor` now prints the distro name and flags PRoot containers
- Distro-aware install hints (pacman / apt / dnf / zypper / apk / brew / pkg)
- Portable `timeout` shim: `timeout --foreground` -> `gtimeout` -> no limit
- System prompt and tool description follow the detected host instead of
  assuming Android/Termux
- `install.sh`: installs the `ai` launcher into a user-writable PATH dir on
  desktop Linux/macOS (no root), skips Termux-only packages elsewhere
- `ai-agent`: hides bubble / autostart menu entries outside Termux and shows
  the host distro instead
- `tests/*.sh`: portable shebangs; the live streaming test tolerates slower
  machines instead of asserting an exact render count

Floating bubble overlay or terminal chat. Pure Bash, bring your own API key.
Repo: github.com/Arkael-Dev/ai-agent
License: GPL-3.0 (derivative of ExTV/termux-bubble)

PROVIDERS (BYOK)
- DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, Ollama, custom
- All via OpenAI-compatible API
- Key stored only on device, no middleman server

TWO MODES
- ai-agent-bubble.sh: draggable floating bubble over any app
- ai-agent-chat.sh: terminal chat, needs only curl and jq

AGENTIC
- Model can read files, run programs, fetch data via run_bash tool
- SSE streaming replies
- Auto-retry on 429/5xx with backoff, real API error messages shown

CLIPBOARD QUICK ACTIONS
- Translate, summarize, explain, fix, reply

SECURITY
- Every command logged to ~/.config/deepseek-bubble/cmd.log
- BASH_CONFIRM=1 requires confirmation for risky commands
- Control character sanitization and transcript length caps

UI
- Conversation history saved and restored on start
- Auto-scroll answer console
- Mic dictation, Send becomes Stop with elapsed timer
- Draggable panel, kept on screen
- Settings screen for provider, key, model

CONFIG
- DEEPSEEK_MAX_TOKENS, DEEPSEEK_THINKING, DEEPSEEK_API_URL
- MAX_RUN_SECONDS per-run budget
- History trimmed automatically to bound context and cost

INSTALL
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
bash install.sh

install.sh sets up packages, adds the "ai" command, optional autostart menu.

REQUIREMENTS
Termux + Termux:GUI + Termux:API, all from the same source.
pkg install termux-gui-bash jq curl termux-api git

NOTES
- If you get model not found, pass --model YOUR_MODEL
- Tool calling needs a capable model; very small local models often fail
- Claude OpenAI-compatible endpoint is experimental

Credit: ExTV (termux-bubble), modified by Arkael-Dev

#AIAgent #Termux #Android #OpenSource
