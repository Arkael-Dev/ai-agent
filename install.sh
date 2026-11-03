#!/usr/bin/env bash
# Based on ExTV/termux-bubble (https://github.com/ExTV/termux-bubble), GPL-3.0.
# Original author: ExTV. Modified by Arkael-Dev.
# One-time setup: dependencies + the `ai` command.  Run:  bash install.sh
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── where does the launcher go? ─────────────────────────────────────────────
# Termux: its own prefix bin.  Otherwise the first user-writable dir in PATH,
# falling back to ~/.local/bin (created on demand) so we never need root.
if [ -n "${TERMUX_VERSION:-}" ] && [ -n "${PREFIX:-}" ]; then
    BIN="$PREFIX/bin"
else
    BIN=""
    IFS=: read -r -a _paths <<<"$PATH"
    for _p in "${_paths[@]}"; do
        case "$_p" in
            ""|/data/*) continue ;;                  # empty entry or Termux's own bin
            "$HOME"/*) [ -w "$_p" ] && { BIN="$_p"; break; } ;;
        esac
    done
    if [ -z "$BIN" ]; then
        BIN="$HOME/.local/bin"
        mkdir -p "$BIN"
    fi
fi

echo "⚡ Installing AI Agent from $DIR"

# ── dependencies ────────────────────────────────────────────────────────────
need=""
for d in curl jq sed grep; do command -v "$d" >/dev/null 2>&1 || need="$need $d"; done

if [ -n "$need" ]; then
    echo "Missing:$need — installing…"
    if command -v pacman >/dev/null 2>&1; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO pacman -S --needed --noconfirm jq curl coreutils grep sed
    elif command -v apt-get >/dev/null 2>&1; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO apt-get update && $SUDO apt-get install -y jq curl coreutils grep sed
    elif command -v dnf >/dev/null 2>&1; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO dnf install -y jq curl coreutils grep sed
    elif command -v zypper >/dev/null 2>&1; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO zypper install -y jq curl coreutils grep sed
    elif command -v apk >/dev/null 2>&1; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
        $SUDO apk add jq curl coreutils grep sed
    elif command -v brew >/dev/null 2>&1; then
        brew install jq curl coreutils grep gnu-sed
    else
        echo "⚠ Install these manually:$need" >&2
    fi
fi

# ── launcher ────────────────────────────────────────────────────────────────
chmod +x "$DIR/ai-agent" "$DIR/ai-agent-chat.sh" 2>/dev/null || true
ln -sf "$DIR/ai-agent" "$BIN/ai"
echo "✓ Command installed: $BIN/ai"
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "  ⚠ $BIN is not in your PATH — add:  export PATH=\"$BIN:\$PATH\"" ;;
esac

# autostart is a Termux-only convenience
if [ -n "${TERMUX_VERSION:-}" ] && [ -n "${PREFIX:-}" ] && [ -t 0 ]; then
    read -r -p "Open the menu automatically whenever Termux starts? [y/N] " a
    case "$a" in y|Y|yes) "$DIR/ai-agent" autostart on ;; esac
fi
echo "Done. Start with:  ai"
