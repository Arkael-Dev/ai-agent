# ⚡ AI Agent — an agentic AI assistant for Linux: terminal chat that actually runs commands

🌐 **English** · [Bahasa Indonesia](README.id.md)

> An agentic AI assistant for Linux. Chat with DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, or a local Ollama model — and let the model read files, run programs, and fetch data on your machine through the `run_bash` tool. Pure Bash, no runtime to install. Bring your own API key.

Works on **Arch, Debian/Ubuntu, Fedora, openSUSE, Alpine, WSL, and macOS**, including inside container images built with `proot-distro` / `chroot`. See [Compatibility](PORTABILITY.md) for the full matrix.

## Purpose

- **One agent, many AIs.** Not locked to a single vendor. Use DeepSeek, ChatGPT, Gemini, Claude, or a local model through Ollama.
- **Bring your own key (BYOK).** No keys live in this repo and there is no middleman server. Your key stays on your machine and is sent only to the provider you choose.
- **An AI that works, not just chats.** The model can read files, run programs, fetch data, and fix things on your system through the `run_bash` tool.
- **Lightweight, pure Bash.** Needs only `bash`, `curl`, and `jq` — no Python, Node, or Docker.
- **Works with or without a desktop.** On a desktop `ai` opens a small GUI menu (via `dialog`/`whiptail`); over SSH, in a tmux pane or on a headless server the same menu is drawn in plain text. No desktop session required.

## Supported providers

All providers use the OpenAI-compatible chat API. DeepSeek remains the **default**.

| Provider | Name (`--provider`) | Key variable | Default model |
|---|---|---|---|
| DeepSeek (default) | `deepseek` | `DEEPSEEK_API_KEY` | `deepseek-flash` |
| OpenAI (ChatGPT) | `openai` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| Google Gemini | `gemini` | `GEMINI_API_KEY` | `gemini-2.5-flash` |
| Anthropic Claude | `claude` | `ANTHROPIC_API_KEY` | `claude-sonnet-5-5` |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` | `openrouter/auto` |
| Groq | `groq` | `GROQ_API_KEY` | `llama-3.3-70b-versatile` |
| Ollama (local) | `ollama` | no key needed | `qwen2.5:3b` |
| Anything else | `custom` | `AI_API_KEY` | set via `AI_MODEL` |

Notes:
- Default model names may go out of date. If you get a *model not found* error, pass `--model YOUR_MODEL`.
- Claude's OpenAI-compatible endpoint is experimental, so tool calling may not be perfect.
- The agentic chat (running commands) needs a model that supports tool calling. Very small local models often fail at this.

## Requirements

- **bash 4 or newer** (macOS ships 3.2 — install a newer one with `brew install bash`)
- **curl** and **jq**
- **git** (to clone and update)

That is all. Install them with your package manager:

| Distro | Command |
|---|---|
| Arch / Manjaro | `sudo pacman -S --needed bash curl jq git` |
| Debian / Ubuntu / Mint | `sudo apt install bash curl jq git` |
| Fedora / RHEL | `sudo dnf install bash curl jq git` |
| openSUSE | `sudo zypper install bash curl jq git` |
| Alpine | `sudo apk add bash curl jq git` |
| macOS | `brew install bash curl jq git` |

Check everything in one shot with:

```
./ai-agent-chat.sh --doctor
```

## Quick start (recommended)

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
bash install.sh
```

`install.sh` detects your package manager, installs the dependencies (asking for `sudo` only when it is needed), and adds a command called **`ai`** to a directory that is already on your `PATH`. After that, just type:

```
ai
```

```
⚡ AI Agent
 AI: deepseek · deepseek-flash · key ✓
 Host: Fedora Linux 41

  1) Chat in terminal
  4) Choose AI / API key / model
  5) Update
  q) Quit
```

On a desktop this menu is drawn as a small window (see [GUI menu](#gui-menu-on-a-desktop));
without a session it is printed as text like the above.

Shortcuts: `ai chat`, `ai setup`, `ai update`, or `ai "your question"` for a one-shot answer.

## Installation (manual)

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x ai-agent-chat.sh ai-agent
./ai-agent-chat.sh            # chat in the terminal
```

On first run you are asked for a **provider**, an **API key**, and a **model**. The key and model are checked with a tiny test request before they are saved.

## GUI menu on a desktop

Run `ai` (or `./ai-agent`) and you get a small window instead of a prompt:

```
┌─ AI Agent ──────────────────────────────┐
│ AI: deepseek · deepseek-flash · key ✓   │
│                                         │
│  1  Chat in a new terminal window       │
│  2  Chat in this terminal               │
│  3  Choose AI / API key / model         │
│  4  Update                              │
│  5  Close                               │
└─────────────────────────────────────────┘
```

This is the same list you get over SSH or in a tty, drawn in a terminal; only a session
with `$DISPLAY` or `$WAYLAND_DISPLAY` set gets the window.

- **Chat in a new terminal window** opens your chat in a fresh terminal emulator
  (gnome-terminal, konsole, xfce4-terminal, alacritty, kitty, foot, xterm, …);
  on macOS it opens Terminal.app. If none is found it tells you to use option 2.
- **Chat in this terminal** hands the current window to the chat.
- No desktop (`$DISPLAY`/`$WAYLAND_DISPLAY` unset) or `AI_NO_GUI=1` → the same
  menu is printed as text, so SSH and tty sessions keep working unchanged.
- `ai gui` forces the window, `ai doctor` shows whether the GUI and a terminal
  emulator were detected.

```
sudo pacman -S dialog      # or: apt install dialog / dnf install dialog
```

Related commands: `ai` · `ai chat` · `ai setup` · `ai update` · `ai doctor` · `ai --help`

## Terminal chat

On start it opens a **menu** where you choose the AI before chatting:

```
⚡ AI Agent — choose your AI
  1) DeepSeek    ✓ key saved          deepseek-flash   ◀ current
  2) OpenAI      ✗ needs API key      gpt-4o-mini
  ...
  7) Ollama      local · no key needed qwen2.5:3b
  Enter = start with DeepSeek · deepseek-flash
  m = choose model   k = change API key   q = quit
```

- **Pick a number** to switch AI. An **API key is required** for every cloud provider (only Ollama, which runs locally, needs none). The key is typed hidden and checked with a tiny test request before it is saved.
- Then you **choose the model** from a numbered list loaded from the provider (type a number, or type any model id yourself).
- **Enter** starts chatting with the current AI. **m** changes only the model, **k** only the API key.

```
./ai-agent-chat.sh                                   # menu, then chat
./ai-agent-chat.sh --no-menu                         # skip the menu, use the saved AI
./ai-agent-chat.sh --provider claude --model claude-opus-5-5
./ai-agent-chat.sh "list the biggest files in my home folder"   # one answer, then exit
cat error.log | ./ai-agent-chat.sh "what does this error mean?"
```

Commands inside the chat:

| Command | What it does |
|---|---|
| `/menu` | Open the AI menu again (provider, key, model) |
| `/key` | Change the API key of the current AI |
| `/models` | List the provider's models and pick one |
| `/model [id]` | Show the model, or set it by id |
| `/provider [name]` | No name: open the menu. With a name: switch to it (asks for a key if needed) |
| `/reset` | Clear the conversation |
| `/confirm on\|off` | Ask before risky shell commands |
| `/help` | Show the commands |
| `/exit` or Ctrl-D | Quit |

Press **Ctrl-C** to stop an answer that is still running. Replies stream in as they are written, and the conversation is kept between runs (`--new` starts fresh).

## Choosing a provider and model

The fastest way is option **4** in the `ai` menu, or `./ai-agent-chat.sh --setup`:

```
./ai-agent-chat.sh --setup --provider openai
```

Or set the key through the environment for a single run:

```
DEEPSEEK_API_KEY=sk-... ./ai-agent-chat.sh --provider deepseek "hello"
```

## Ollama (local models)

Run Ollama locally and the agent talks to it without any key or internet access:

```
ollama serve
ollama pull qwen2.5:3b
./ai-agent-chat.sh --provider ollama --model qwen2.5:3b
```

Set `OLLAMA_HOST` in the config file if the server is not on `127.0.0.1:11434`. Note that small local models often cannot call tools, which breaks the agentic part.

## Custom provider

Anything that speaks the OpenAI-compatible chat API works. Set `AI_BASE_URL` and `AI_MODEL` in the config file and use `--provider custom`.

## Command-line options

| Option | What it does |
|---|---|
| `--provider NAME` | Choose the provider |
| `--model ID` | Choose the model |
| `--setup` | Open the AI menu only, then exit |
| `--no-menu` | Skip the menu and use the saved settings |
| `--new` | Start with an empty conversation |
| `--doctor` | Print platform and dependency status |
| `--help` | Show help |

## Configuration

File: `~/.config/ai-agent/config` (mode `600`, readable only by you).

| Variable | Purpose |
|---|---|
| `AI_PROVIDER` | Active provider |
| `AI_MODEL` | Model to use (overrides the default) |
| `AI_BASE_URL` | Endpoint URL for the `custom` provider |
| `OLLAMA_HOST` | Address of the Ollama server |
| `AI_THINKING` | `off` (fast, default), `on`, or `default` (DeepSeek only) |
| `AI_MAX_TOKENS` | Maximum answer tokens |
| `BASH_CONFIRM` | `1` = ask for confirmation before risky commands |

Conversation history is stored in `history-cli.json` in the same folder and is deleted on **Reset**. Every command the AI runs is logged to `cmd.log`.

## Security — please read

The agentic chat can **run shell commands on your machine**. Use it carefully:

- Turn on confirmation for risky commands (`rm`, `mv`, `chmod`, `dd`, `reboot`, and similar) by adding `BASH_CONFIRM=1` to the config file, or use `/confirm on`. Risky commands then ask `y/N` before running.
- Do not ask the AI to process text or repositories from sources you do not trust. They may contain hidden instructions that try to make the AI run harmful commands.
- Check `cmd.log` to see everything that has been executed.
- **Never share or commit your API keys.** Do not use someone else's key sent to you in a chat. Shared keys can be revoked at any time, and the owner can see all of your usage.
- On a shared server, remember that the agent runs with *your* user's permissions. Use a dedicated user or a container if you do not trust what it might do.
- Your messages are sent to the provider you choose. Do not paste secrets.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `needs bash 4 or newer` | macOS ships bash 3.2: `brew install bash`, then run with `/opt/homebrew/bin/bash ./ai-agent-chat.sh` |
| `jq: command not found` | Install jq with your package manager (see [Requirements](#requirements)) |
| `Invalid key` | Check the key, provider, and model. Try a different `--model` |
| `model not found` | Default model names change; pass `--model` with a valid id |
| Something else looks wrong | Run `./ai-agent-chat.sh --doctor` and check the platform line |
| Running inside a container | `--doctor` reports `proot`/`chroot` explicitly; the terminal chat works normally |

## Development

- `tests/test-stream-parser.sh` — offline SSE parser tests
- `tests/test-stream-live.sh` — live streaming checks against a mock endpoint

```
bash tests/test-stream-parser.sh
```

Contributions via Issues and Pull Requests are welcome.

## License and credits

GPL-3.0, see [LICENSE](LICENSE).

- **Original author:** [ExTV](https://github.com/ExTV), creator of [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble), which this project is based on.
- **Modified by:** [Arkael-Dev](https://github.com/Arkael-Dev): multi-provider support, terminal chat, portable Linux/macOS support, the `ai` launcher and installer, and other changes.

Thanks to ExTV (author of termux-bubble) for the original design this project grew out of.
