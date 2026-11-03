# Changelog

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
