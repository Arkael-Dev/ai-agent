# Changelog

## Unreleased

### Fixed

- **Custom AI accepted anything as the endpoint URL.** A model name typed at the
  `Endpoint URL` prompt (e.g. `Atria-Dawn`) was saved and ended in
  `curl: (6) Could not resolve host`. The prompt now only accepts `http(s)://` URLs and
  re-asks otherwise; `q` cancels. A base URL such as `https://host/v1` is completed to
  `.../chat/completions`.
- **Empty model was allowed**, giving `HTTP 400: Missing model` on every message. Pressing
  Enter with no model now asks again, and `[s] save anyway` refuses to save an empty model
  or a `Missing model` / 403 / 404 rejection.
- **Typing a list number at the `type an id` prompt** (e.g. `9`) was taken as the model id
  `9`. It now explains that it is a list number and points to `l`.
- **`q` at a model prompt was taken as the model id `q`** (then `404: No active credentials
  for provider: openai`). `q` now cancels the model prompt and the list, leaving the
  previous model untouched.
- **Model list failures were silent.** `Could not load the model list` now shows the
  reason (for example `HTTP 403: rate limited` or a network error).
- **KamiHub model list.** For endpoints on `kamihub.us.ci` the model picker now lists the
  ids from its model page first (`atmoro/atmo/...`, `atmoro/alicn/...`), instead of burying
  them among ids the key cannot use (`atmoro/ali/...`). Update the list in
  `provider_presets` when KamiHub changes its models.
- **`model_not_allowed` hint.** When a gateway rejects the model for your key, the check
  now says so and tells you to pick another id with `m`.

## 1.1.2

Focus: Gemini 3.x tool calls work again.

### Fixed

- **Gemini 3.x rejected every tool result with `HTTP 400: Function call is missing a
  thought_signature in functionCall parts`.** Gemini 3 returns an opaque
  `extra_content.google.thought_signature` on each `tool_calls` entry and requires it
  back when the assistant turn is replayed. The stream parser dropped the field, so the
  second request of every tool loop failed. Both parsers (`ai-agent-chat.sh`,
  `ai-agent-bubble.sh`) now keep it and send it back.

### Changed

- **Gemini default model is now `gemini-3.5-flash`** (was `gemini-2.5-flash`).
  Google answers 2.5 models with `404 This model models/gemini-2.5-flash is no longer
  available to new users. Please update your code to use models/gemini-3.8-flash`.
- **Model picker lists models that still exist:** `gemini-3.5-flash`,
  `gemini-3.5-flash-lite`, `gemini-3.6-flash`, `gemini-3.7-flash`, `gemini-3.8-flash`,
  `gemini-3-flash-preview`, `gemini-3.1-pro-preview`, `gemini-pro-latest`.

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
