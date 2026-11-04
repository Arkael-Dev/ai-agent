# Changelog

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
