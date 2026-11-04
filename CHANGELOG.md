# Changelog

## 1.1.1

Focus: stop a wrong-provider key from being saved and silently breaking every request.

### Fixed

- **A key for another provider could be stored under the wrong provider.** Pointing
  the provider at Gemini while keeping the saved value (`Enter = keep`) stored the
  DeepSeek key (`sk-64…938b`) as `GEMINI_API_KEY`; every later Gemini request then
  answered `HTTP 400: Please pass a valid API key`. The setup check now rejects the
  key, and "save anyway" refuses it too.
- **Key shape is checked against the provider** (`key_shape_warn()`):
  `gemini=AIza…`, `claude=sk-ant-…`, `openrouter=sk-or-v1-…`, `groq=gsk_…`.
  A key that looks like another provider's is named explicitly
  ("that looks like a DeepSeek/OpenAI key (sk-…), not a Gemini key (AIza…)").
- Terminal chat asks for confirmation before using a wrongly-shaped key; the bubble
  refuses it with a toast naming the reason.

### Notes

- If `GEMINI_API_KEY` already holds a DeepSeek/OpenAI key, clear it and run
  `./ai-agent-chat.sh --setup` with a key from
  <https://aistudio.google.com/apikey> (prefix `AIza`).

## 1.1.0

Focus: Gemini works out of the box, and API errors are readable again.

### Fixed

- **Gemini default model.** The shipped default `gemini-2.5-flash-lite` returns
  `HTTP 404 ... is no longer available to new users` on new accounts. The default
  is now `gemini-2.5-flash`, in both the config default and the setup menu.
- **Error bodies shaped as arrays were shown as empty.** Gemini (and some
  gateways) return `[{"error":{"code":404,"message":"..."}}]`, so
  `jq -r '.error.message'` produced nothing and the UI printed `HTTP 404:` with no
  reason. A new `api_err_msg()` helper reads both the object and the array shape,
  and is used everywhere chat, the bubble and the setup check report an API error.
- **Model list full of non-chat models.** `/models` filtering now also drops
  `deep-research`, `computer-use`, `robotics`, `antigravity`, `live`, `lyria`,
  `nano-banana`, `omni`, `aqa` and `gemma`.

### Added

- `--version` flag in `ai-agent-bubble.sh` and `ai-agent-chat.sh`.
- Gemini model presets in the model picker (`gemini-2.5-flash`, `gemini-2.5-pro`,
  `gemini-3.5-flash`, `gemini-3.5-flash-lite`, `gemini-3.8-flash`,
  `gemini-pro-latest`), merged with the live list from the API.

### Verified

- `--provider gemini --model gemini-2.5-flash` answers normally, including the
  `run_bash` tool loop.
- A retired model id now produces a readable error instead of a blank one.
- `bash -n` clean; `tests/test-stream-live.sh` and `tests/test-stream-parser.sh` pass.
