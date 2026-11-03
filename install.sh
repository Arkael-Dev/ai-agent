#!/data/data/com.termux/files/usr/bin/bash
# Based on ExTV/termux-bubble (https://github.com/ExTV/termux-bubble), GPL-3.0.
# Original author: ExTV. Modified by Arkael-Dev.
# One-time setup: dependencies + the `ai` command.  Run:  bash install.sh
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin"

echo "⚡ Installing AI Agent from $DIR"
pkg install -y jq curl coreutils git termux-api termux-gui-bash || \
    echo "(some packages could not be installed — check your connection / mirror)"
chmod +x "$DIR/ai-agent" "$DIR/ai-agent-chat.sh" "$DIR/ai-agent-bubble.sh"
ln -sf "$DIR/ai-agent" "$BIN/ai"
echo "✓ Command installed: type  ai  in Termux"

if [ -t 0 ]; then
    read -r -p "Open the menu automatically whenever Termux starts? [y/N] " a
    case "$a" in y|Y|yes) "$DIR/ai-agent" autostart on ;; esac
fi
echo "Done. Start with:  ai"
