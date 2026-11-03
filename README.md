# ⚡ AI Bubble — a floating AI assistant for Android (Termux)

🌐 **English** · [Bahasa Indonesia](README.id.md)

> A floating, agentic AI assistant that overlays every Android app. Bring your own API key: DeepSeek (default), OpenAI, Gemini, Claude, OpenRouter, Groq, or a local Ollama model. Pure Termux + Termux:GUI bash.

A small draggable bubble floats over every app. Tap it to open a panel with **clipboard quick-actions** (translate, summarize, explain, fix, reply) and an **agentic chat** where the model can run shell commands on your phone to actually get things done.

## Purpose

- **One bubble, many AIs.** Not locked to a single vendor. Use DeepSeek, ChatGPT, Gemini, Claude, or a local model through Ollama.
- **Bring your own key (BYOK).** No keys live in this repo and there is no middleman server. Your key stays on your phone and is sent only to the provider you choose.
- **An AI that works, not just chats.** The model can read files, run programs, fetch data, and fix things on your device through the `run_bash` tool.
- **Lightweight, pure Bash.** All you need is Termux, Termux:GUI, `curl`, and `jq`.

This project is derived from [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble) (GPL-3.0), with multi-provider support added.

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

Install **three apps** from the **same source** (all from F-Droid, or all from GitHub Releases). Do not mix them: different signing keys make Android refuse to install the plugins.

- [Termux](https://github.com/termux/termux-app/releases)
- [Termux:GUI](https://github.com/termux/termux-gui/releases), the overlay engine
- [Termux:API](https://github.com/termux/termux-api/releases), for clipboard, toast, and speech

Do not use the Play Store builds; they are outdated.

Then, in Termux:

```
pkg update && pkg install termux-gui-bash jq curl termux-api git
```

Grant Termux:GUI the **Display over other apps** permission (Settings > Apps > Termux:GUI).

## Installation

```
git clone https://github.com/Arkael-Dev/ai-agent
cd ai-agent
chmod +x deepseek-bubble.sh
./deepseek-bubble.sh
```

On first launch the panel opens the **Settings** screen. Pick your **provider**, paste your **API key**, choose a **model**, and tap **Save**. The key and model are checked before they are saved.

## Choosing a provider and model

**In the app (easiest):** tap the **⚙** button in the panel header.

- **Provider ▸** cycles through DeepSeek, OpenAI, Gemini, Claude, OpenRouter, Groq, and Ollama.
- **API key:** paste your own key. Leave it empty to keep the key already saved for that provider.
- **Model:** type any model id, or tap **Models** to load the list from your provider and tap again to step through it.
- **Save** checks the key and model with a tiny test request, then stores them. **Cancel** goes back without changes.

**From the command line**, use flags or environment variables:

```
./deepseek-bubble.sh                                    # DeepSeek (default)
./deepseek-bubble.sh --provider openai                  # ChatGPT
./deepseek-bubble.sh --provider gemini --model gemini-2.5-pro
./deepseek-bubble.sh --provider ollama --model qwen2.5:3b
```

Or pass the key through the environment:

```
OPENAI_API_KEY="sk-..." ./deepseek-bubble.sh --provider openai
```

Every key you have saved is kept, so you can switch providers without re-entering anything.

### Ollama (local models)

No key and no internet needed. Make sure the Ollama server is running, then:

```
./deepseek-bubble.sh --provider ollama --model qwen2.5:3b
```

If Ollama runs on a PC on the same network, point to it with:

```
OLLAMA_HOST="http://192.168.1.10:11434" ./deepseek-bubble.sh --provider ollama
```

Large models are heavy for a phone. On a phone, pick a small model (around 1–3B parameters).

### Custom provider

For any other OpenAI-compatible service:

```
AI_BASE_URL="https://example.com/v1/chat/completions" AI_API_KEY="..." AI_MODEL="model-name" ./deepseek-bubble.sh --provider custom
```

## Usage

- **Drag** the bubble anywhere, **tap** it to open the panel.
- **Clipboard actions:** copy text in any app, then tap *Trans / Sum / Expl / Fix / Reply*.
- **Chat:** type a request and tap **Send**. The model can run bash commands on your phone to complete the task. Tap **Stop** to cancel.
- **Copy / Speak:** copy or read aloud the last answer. **Mic** for voice input.
- **Reset** clears the conversation. **▽** collapses the panel. **✕** quits.
- **⚙** opens Settings to change provider, key, and model at any time.
- **Moving the panel:** drag it by the header area (the title row). You can also tap **▽** to collapse it into the bubble, drag the bubble anywhere, then tap it to reopen.

Command-line options:

| Option | What it does |
|---|---|
| `--provider NAME` | Choose the provider |
| `--model ID` | Choose the model |
| `--update` | Runs `git pull` to update |
| `--help` | Show help |

## Configuration

File: `~/.config/deepseek-bubble/config` (mode `600`, readable only by you).

| Variable | Purpose |
|---|---|
| `AI_PROVIDER` | Active provider |
| `AI_MODEL` | Model to use (overrides the default) |
| `AI_BASE_URL` | Endpoint URL for the `custom` provider |
| `OLLAMA_HOST` | Address of the Ollama server |
| `DEEPSEEK_THINKING` | `off` (fast, default), `on`, or `default` (DeepSeek only) |
| `DEEPSEEK_MAX_TOKENS` | Maximum answer tokens |
| `BASH_CONFIRM` | `1` = ask for confirmation before risky commands |

Conversation history is stored in `history.json` in the same folder and is deleted on **Reset**. Every command the AI runs is logged to `cmd.log`.

## Security — please read

The agentic chat can **run shell commands on your phone**. Use it carefully:

- Turn on confirmation for risky commands (`rm`, `mv`, `chmod`, `dd`, `reboot`, and similar) by adding `BASH_CONFIRM=1` to the config file. Those commands will wait until you tap **Run**.
- Do not ask the AI to process text or repositories from sources you do not trust. They may contain hidden instructions that try to make the AI run harmful commands.
- Check `cmd.log` to see everything that has been executed.
- **Never share or commit your API keys.** Do not use someone else's key sent to you in a chat. Shared keys can be revoked at any time, and the owner can see all of your usage.
- Clipboard text and your messages are sent to the provider you choose. Do not copy secrets when using the quick actions.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `bad interpreter: tgui-bash` | Run `pkg install termux-gui-bash` |
| Termux:GUI "App not installed" | The app source differs from Termux. Check with `termux-info \| grep -i apk`, then install from the same source (F-Droid or GitHub) |
| Bubble does not appear | Enable *Display over other apps* for Termux:GUI and make sure the app is installed |
| `Invalid key` | Check the key, provider, and model. Try a different `--model` |
| Clipboard, toast, or speech not working | Install `termux-api` and the Termux:API app |
| `SCREEN_H_PX: unbound variable` | Fixed in this version. Run `./deepseek-bubble.sh --update` |
| Panel will not drag | Drag from the title row. If it still fails, collapse with **▽**, move the bubble, and reopen. To report it, run with `DRAG_DEBUG=1` and share `~/.config/deepseek-bubble/touch.log`. You can also raise `DRAG_EXTRA_PX` (default 110) |

## Development

- GitHub Actions runs syntax and ShellCheck checks on every push (see `.github/workflows`).
- Planned: an agent mode that fixes code in a repo on its own (read errors, edit, run checks, then show a diff for approval), image generation support, and a fuller update command.

Contributions via Issues and Pull Requests are welcome.

## License and credits

GPL-3.0, see [LICENSE](LICENSE). Based on [ExTV/termux-bubble](https://github.com/ExTV/termux-bubble). Thanks to ExTV and to the authors of Termux and Termux:GUI.
