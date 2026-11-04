#!/data/data/com.termux/files/usr/bin/tgui-bash
# Based on ExTV/termux-bubble (https://github.com/ExTV/termux-bubble), GPL-3.0.
# Original author: ExTV. Modified by Arkael-Dev.
set -u

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  AI Agent Bubble — an agentic floating AI assistant for Android/Termux   ║
# ║                                                                          ║
# ║  • A tiny draggable bubble floats over every app.                        ║
# ║  • Tap it to open a panel: clipboard quick-actions + an agentic chat     ║
# ║    where the model can run shell commands on the device (run_bash).      ║
# ║  • Multi-provider: DeepSeek (default), OpenAI, Gemini, Claude, Ollama…   ║
# ║  • First run asks for your own API key and stores it privately.          ║
# ║                                                                          ║
# ║  Needs: the "Display over other apps" permission for Termux:GUI,         ║
# ║         and `curl` + `jq` (both standard in Termux).                     ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── CLI flags ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
VERSION="1.1.0"
CLI_PROVIDER=""; CLI_MODEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --provider) CLI_PROVIDER="${2:-}"; shift 2 ;;
        --model)    CLI_MODEL="${2:-}"; shift 2 ;;
        --version) echo "ai-agent-bubble.sh $VERSION"; exit 0 ;;
        --update)
            if [ -d "$SCRIPT_DIR/.git" ]; then
                git -C "$SCRIPT_DIR" pull --ff-only && echo "Updated."
            else
                echo "Not a git checkout: $SCRIPT_DIR" >&2
            fi
            exit 0 ;;
        -h|--help)
            cat <<'HELP'
Usage: ai-agent-bubble.sh [--provider NAME] [--model ID] [--update] [--version]
Providers: deepseek (default) openai gemini claude openrouter groq ollama custom
Keys (env or ~/.config/ai-agent/config):
  DEEPSEEK_API_KEY OPENAI_API_KEY GEMINI_API_KEY ANTHROPIC_API_KEY
  OPENROUTER_API_KEY GROQ_API_KEY   (ollama needs no key)
Other env: AI_PROVIDER AI_MODEL AI_BASE_URL (full chat/completions URL, for "custom")
In the app: tap the gear button to choose provider, key and model.
HELP
            exit 0 ;;
        *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
    esac
done

# ── Provider presets (all speak the OpenAI chat/completions dialect) ─────────
KNOWN_PROVIDERS="deepseek openai gemini claude openrouter groq ollama custom"
api_err_msg() {   # short human message from an API error body on stdin (object / array-of-objects shapes)
    jq -r 'def m(x): if (x|type)=="object" then (x.message // empty)
                     elif (x|type)=="array" then (x[0] | m(.))
                     else empty end;
           if type=="array" then (.[0].error | m(.)) // (.[0] | m(.))
           else (.error | m(.)) // m(.) end' 2>/dev/null | tr '\n' ' ' | cut -c1-300
}

provider_url() {
    case "$1" in
        deepseek)   echo "https://api.deepseek.com/chat/completions" ;;
        openai)     echo "https://api.openai.com/v1/chat/completions" ;;
        gemini)     echo "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" ;;
        claude)     echo "https://api.anthropic.com/v1/chat/completions" ;;
        openrouter) echo "https://openrouter.ai/api/v1/chat/completions" ;;
        groq)       echo "https://api.groq.com/openai/v1/chat/completions" ;;
        ollama)     echo "${OLLAMA_HOST:-http://localhost:11434}/v1/chat/completions" ;;
        *)          echo "${AI_BASE_URL:-}" ;;
    esac
}
provider_model() {
    case "$1" in
        deepseek)   echo "deepseek-flash" ;;
        openai)     echo "gpt-4o-mini" ;;
        gemini)     echo "gemini-2.5-flash" ;;
        claude)     echo "claude-sonnet-5-5" ;;
        openrouter) echo "openrouter/auto" ;;
        groq)       echo "llama-3.3-70b-versatile" ;;
        ollama)     echo "qwen2.5:3b" ;;
        *)          echo "${AI_MODEL:-}" ;;
    esac
}
provider_label() {
    case "$1" in
        deepseek) echo "DeepSeek" ;; openai) echo "OpenAI" ;; gemini) echo "Gemini" ;;
        claude) echo "Claude" ;; openrouter) echo "OpenRouter" ;; groq) echo "Groq" ;;
        ollama) echo "Ollama" ;; *) echo "Custom AI" ;;
    esac
}
provider_keyvar() {   # name of the variable holding this provider's key
    case "$1" in
        deepseek) echo DEEPSEEK_API_KEY ;; openai) echo OPENAI_API_KEY ;;
        gemini) echo GEMINI_API_KEY ;; claude) echo ANTHROPIC_API_KEY ;;
        openrouter) echo OPENROUTER_API_KEY ;; groq) echo GROQ_API_KEY ;;
        ollama) echo OLLAMA_API_KEY ;; *) echo AI_API_KEY ;;
    esac
}

# ── Configuration ────────────────────────────────────────────────────────────
CONFIG_DIR="${AI_CONFIG_DIR:-$HOME/.config/ai-agent}"
# one-time move of the settings folder used by earlier versions
if [ -z "${AI_CONFIG_DIR:-}" ] && [ ! -d "$CONFIG_DIR" ] && [ -d "$HOME/.config/deepseek-bubble" ]; then
    mv "$HOME/.config/deepseek-bubble" "$CONFIG_DIR" 2>/dev/null
fi
CONFIG_FILE="$CONFIG_DIR/config"
DEFAULT_API_URL="https://api.deepseek.com/chat/completions"
DEFAULT_MODEL="deepseek-flash"   # current DeepSeek id; deepseek-v4-pro is the bigger one
DEFAULT_MAX_TOKENS=8000
DEFAULT_THINKING="off"           # off = fastest answers; on = reasoning pass; default = let the server decide
DEFAULT_CONFIRM_DANGEROUS=0      # 1 = ask before risky shell commands
MAX_RUN_SECONDS=300              # wall-clock cap for one agent run (all iterations)
HTTP_RETRIES=2                   # retries for 429 / 5xx
RISKY_PATTERN='(^|[;&|(]|&&|\|\|)[[:space:]]*(rm|rmdir|shred|mkfs|dd|truncate|mv|chmod|chown|pm[[:space:]]+(un)?install|am[[:space:]]+force-stop|settings[[:space:]]+put|reboot|svc[[:space:]]|cmd[[:space:]]|termux-clipboard-set)'
MAX_ITERS=25            # agent tool-call loop cap
CMD_TIMEOUT=120         # per run_bash timeout (seconds)
OUT_LIMIT=10000         # max chars of tool output fed back to the model
HIST_LIMIT=60000        # trim conversation history to roughly this many chars between turns
HIST_HARD_LIMIT=240000  # emergency trim during a single agent run
TRANS_LIMIT=16000       # max chars kept in the on-screen transcript
EDGE_KEEP=60            # px of the bubble kept on-screen when dragging
DRAG_EXTRA_PX="${DRAG_EXTRA_PX:-110}"   # extra px below the title that still start a panel drag (status-bar offset)

SYSTEM_PROMPT="You are a helpful assistant living in a floating bubble on the user's Android phone, running inside Termux (Bionic libc, no sudo/root). You can run bash commands on the device with the run_bash tool to inspect files, run programs, fetch things, and get tasks done. Prefer doing the work with tools over describing it. Keep answers concise and mobile-friendly."

# run_bash tool schema (sent to the API)
TOOLS='[{"type":"function","function":{"name":"run_bash","description":"Run a bash command on the Android/Termux device and return combined stdout+stderr plus the exit code. Use for files, processes, network — anything.","parameters":{"type":"object","properties":{"command":{"type":"string","description":"The bash command to run."}},"required":["command"]}}}]'

# ── Dependencies / scratch space ─────────────────────────────────────────────
for _dep in curl jq timeout tr; do
    command -v "$_dep" >/dev/null 2>&1 || {
        echo "Missing dependency: $_dep — run: pkg install curl jq coreutils" >&2
        exit 1
    }
done
command -v termux-clipboard-get >/dev/null 2>&1 || \
    echo "Warning: termux-api not found — clipboard actions, toasts and speech won't work (pkg install termux-api + the Termux:API app)." >&2

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-agent.XXXXXX")" || exit 1
# tgui-bash installed an EXIT trap that kills its helper coprocs; keep that
# behaviour and add our temp cleanup on top.
trap 'rm -rf "$TMP_DIR" >/dev/null 2>&1; set +u; kill -9 $tg__main_PID >/dev/null 2>&1; kill -9 $tg__event_PID >/dev/null 2>&1' EXIT

PROVIDER="${AI_PROVIDER:-deepseek}"
API_URL="$DEFAULT_API_URL"
ACTIVE_MODEL="$DEFAULT_MODEL"      # name kept for compatibility: it is the active model id
MAX_TOKENS="$DEFAULT_MAX_TOKENS"
THINKING="$DEFAULT_THINKING"
CONFIRM_DANGEROUS="$DEFAULT_CONFIRM_DANGEROUS"
API_KEY=""
# one key slot per provider, so switching never loses a key
declare -A KEYS=()
declare -A MODELS=()
CUSTOM_URL="${AI_BASE_URL:-}"
HIST_FILE="$CONFIG_DIR/history.json"
CMD_LOG="$CONFIG_DIR/cmd.log"

load_config() {
    local line v k cfg_provider="" cfg_model="" cfg_url="" kv
    if [ -f "$CONFIG_FILE" ]; then
        # split on the FIRST '=' only, keeping any '=' inside the value
        while IFS= read -r line || [ -n "$line" ]; do
            v="${line#*=}"
            case "$line" in
                AI_PROVIDER=*)         cfg_provider="$v" ;;
                AI_MODEL=*)            cfg_model="$v" ;;
                AI_BASE_URL=*)         CUSTOM_URL="${CUSTOM_URL:-$v}" ;;
                DEEPSEEK_MODEL=*)      [ -n "$v" ] && MODELS[deepseek]="$v" ;;   # legacy key
                DEEPSEEK_API_URL=*)    cfg_url="$v" ;;                           # legacy key
                AI_MAX_TOKENS=*|DEEPSEEK_MAX_TOKENS=*) [ -n "$v" ] && MAX_TOKENS="$v" ;;
                AI_THINKING=*|DEEPSEEK_THINKING=*)     [ -n "$v" ] && THINKING="$v" ;;
                BASH_CONFIRM=*)        [ -n "$v" ] && CONFIRM_DANGEROUS="$v" ;;
                MODEL_*=*)             k="${line%%=*}"; k="${k#MODEL_}"; [ -n "$v" ] && MODELS[$k]="$v" ;;
                *_API_KEY=*)           k="${line%%=*}"; [ -n "$v" ] && KEYS[$k]="$v" ;;
            esac
        done < "$CONFIG_FILE"
    fi
    # environment wins over the file (standard variable names per provider)
    for k in $KNOWN_PROVIDERS; do
        kv="$(provider_keyvar "$k")"
        [ -n "${!kv:-}" ] && KEYS[$kv]="${!kv}"
    done
    [ -z "${AI_PROVIDER:-}" ] && [ -n "$cfg_provider" ] && PROVIDER="$cfg_provider"
    [ -n "$CLI_PROVIDER" ] && PROVIDER="$CLI_PROVIDER"
    case " $KNOWN_PROVIDERS " in *" $PROVIDER "*) ;; *) PROVIDER=deepseek ;; esac
    activate_provider "$PROVIDER"
    # explicit model overrides: --model > AI_MODEL env > config AI_MODEL (only for the saved provider)
    if   [ -n "$CLI_MODEL" ];       then ACTIVE_MODEL="$CLI_MODEL"
    elif [ -n "${AI_MODEL:-}" ];    then ACTIVE_MODEL="$AI_MODEL"
    elif [ -n "$cfg_model" ] && [ "$PROVIDER" = "$cfg_provider" ]; then ACTIVE_MODEL="$cfg_model"
    fi
    # legacy DEEPSEEK_API_URL only applies to deepseek
    [ "$PROVIDER" = deepseek ] && [ -n "$cfg_url" ] && API_URL="$cfg_url"
}

# point API_URL / API_KEY / model at the given provider
activate_provider() {
    local p="$1" kv
    PROVIDER="$p"
    API_URL="$(provider_url "$p")"
    [ "$p" = custom ] && [ -n "$CUSTOM_URL" ] && API_URL="$CUSTOM_URL"
    ACTIVE_MODEL="${MODELS[$p]:-$(provider_model "$p")}"
    kv="$(provider_keyvar "$p")"
    API_KEY="${KEYS[$kv]:-}"
    # Ollama runs locally and needs no key; the header just has to be non-empty
    [ "$p" = ollama ] && [ -z "$API_KEY" ] && API_KEY="ollama"
    # the OpenAI API wants max_completion_tokens; everyone else still takes max_tokens
    if [ "$p" = openai ]; then TOKEN_FIELD="max_completion_tokens"; else TOKEN_FIELD="max_tokens"; fi
}

save_config() {
    local k kv m
    MODELS[$PROVIDER]="$ACTIVE_MODEL"
    KEYS[$(provider_keyvar "$PROVIDER")]="$API_KEY"
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR" 2>/dev/null
    (
        umask 077
        {
            printf 'AI_PROVIDER=%s\n' "$PROVIDER"
            printf 'AI_BASE_URL=%s\n' "$CUSTOM_URL"
            printf 'AI_MAX_TOKENS=%s\nAI_THINKING=%s\nBASH_CONFIRM=%s\n' \
                "$MAX_TOKENS" "$THINKING" "$CONFIRM_DANGEROUS"
            for k in $KNOWN_PROVIDERS; do
                kv="$(provider_keyvar "$k")"
                [ -n "${KEYS[$kv]:-}" ] && [ "${KEYS[$kv]}" != ollama ] && printf '%s=%s\n' "$kv" "${KEYS[$kv]}"
                m="${MODELS[$k]:-}"
                [ -n "$m" ] && printf 'MODEL_%s=%s\n' "$k" "$m"
            done
        } > "$CONFIG_FILE"
    )
    chmod 600 "$CONFIG_FILE" 2>/dev/null
}

load_config
case "$MAX_TOKENS" in ''|*[!0-9]*) MAX_TOKENS="$DEFAULT_MAX_TOKENS" ;; esac
PROVIDER_LABEL="$(provider_label "$PROVIDER")"

# ── Small helpers ────────────────────────────────────────────────────────────
toast() { termux-toast -g top "$1" >/dev/null 2>&1 & }

# get_text: read an EditText/TextView's text. MUST run in main context (not $()),
# because the bindings' own getText pipes the coproc read and corrupts the fd.
# Result is returned in the global REPLY.
get_text() {
    declare -A _gp=([aid]="$aid" [id]="$1")
    tg_json_send getText _gp
    local r; r="$(tg_msg_recv)"
    REPLY="$(printf '%s' "$r" | jq -r '.')"
}

# ── Busy handling ────────────────────────────────────────────────────────────
# API calls and tool commands run in background jobs while we keep draining UI
# events, so the bubble stays responsive: ✕ quits, ▽ collapses, drag works, and
# Send turns into a Stop button that cancels the current run.
CANCEL=0

BUSY=0; PENDING=0; APPROVE=0
busy_pump() {   # handle any queued UI events while an API call / command runs
    local n=0
    while [ "$n" -lt 60 ] && ev_ready; do
        n=$((n+1))
        recv_ev || break
        handle_event "$EV"
    done
}

busy_begin() { BUSY=1; CANCEL=0; tg_view_text "$aid" "$send_btn" "Stop"; }
busy_end()   { BUSY=0; CANCEL=0; tg_view_text "$aid" "$send_btn" "Send"; }

# ── Chat API (OpenAI-compatible; DeepSeek by default) ─────────────────────────────────────────────────────────────
API_RESP=""
CURL_ERR=""
HTTP_CODE=""
api_post() {   # $1 = JSON body -> sets API_RESP, HTTP_CODE; returns 0=ok 1=error 2=cancelled
    API_RESP=""; CURL_ERR=""; HTTP_CODE=""
    local attempt=0 bodyf="$TMP_DIR/body.json" respf="$TMP_DIR/resp.json" \
          errf="$TMP_DIR/curl.err" codef="$TMP_DIR/curl.code" pid ec
    POST_T0=$SECONDS; POST_LASTT=-1
    # body via file: request bodies can exceed the kernel's 128KiB per-argument limit
    printf '%s' "$1" >"$bodyf"
    while :; do
        : >"$respf"; : >"$errf"; : >"$codef"
        curl -sS --max-time 240 "$API_URL" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            --data-binary @"$bodyf" -o "$respf" -w '%{http_code}' >"$codef" 2>"$errf" &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            busy_pump
            # elapsed-time feedback while the request is in flight
            if [ $((SECONDS - POST_T0)) -ne "$POST_LASTT" ]; then
                POST_LASTT=$((SECONDS - POST_T0))
                tg_view_text "$aid" "$send_btn" "Stop ${POST_LASTT}s"
            fi
            if [ "$CANCEL" = 1 ]; then
                kill "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                return 2
            fi
            sleep 0.2
        done
        wait "$pid" 2>/dev/null; ec=$?
        HTTP_CODE="$(cat "$codef" 2>/dev/null)"
        API_RESP="$(cat "$respf" 2>/dev/null)"
        CURL_ERR="$(head -c 200 "$errf" 2>/dev/null | tr -d '\n')"
        # transient server-side failures are worth another try; 4xx never is
        case "$HTTP_CODE" in
            429|500|502|503|504)
                if [ "$attempt" -lt "$HTTP_RETRIES" ]; then
                    attempt=$((attempt+1))
                    toast "Retrying (HTTP $HTTP_CODE)…"
                    sleep "$attempt"
                    continue
                fi ;;
        esac
        break
    done
    if [ "$ec" -ne 0 ]; then
        [ -z "$CURL_ERR" ] && CURL_ERR="curl exit $ec"
        return 1
    fi
    if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" -ge 400 ] 2>/dev/null; then
        CURL_ERR="HTTP $HTTP_CODE$( api_err_msg <<<"$API_RESP")"
        return 1
    fi
    return 0
}

# Build the request body from a messages array on stdin. One place for model,
# token cap and thinking mode so the one-shot and agent paths stay in sync.
json_body() {   # $1 = "tools" to send the tool schema, $2 = "stream" to stream
    jq -c --arg m "$ACTIVE_MODEL" --argjson mt "${MAX_TOKENS:-8000}" \
          --arg th "$THINKING" --argjson tools "$TOOLS" --arg mode "${1:-notools}" \
          --arg stream "${2:-off}" --arg tf "$TOKEN_FIELD" --arg prov "$PROVIDER" '
        {model:$m, messages:.} + {($tf):$mt}
        + (if $prov != "deepseek" then {}
           elif $th == "off" then {thinking:{type:"disabled"}}
           elif $th == "on" then {thinking:{type:"enabled"}}
           else {} end)
        + (if $mode == "tools" then {tools:$tools, tool_choice:"auto"} else {} end)
        + (if $stream == "stream" then {stream:true} else {} end)'
}

# ── Streaming (SSE) ─────────────────────────────────────────────────────────
# BEGIN STREAM BLOCK — kept contiguous so the parser can be unit-tested on its own
STREAM_FILE=""
STREAM_STATE=""
STREAM_TEXT=""
STREAM_LINES=0
STREAM_TOOLS=0

stream_reset() {
    STREAM_FILE="$TMP_DIR/resp.stream"
    STREAM_STATE="$TMP_DIR/stream.state"
    : >"$STREAM_FILE"
    printf '%s\n' '{"content":"","tools":{},"finish":null}' >"$STREAM_STATE"
    STREAM_TEXT=""; STREAM_LINES=0; STREAM_TOOLS=0
}

# merge a batch of `choices[0].delta` objects (JSON array on stdin) into the state
stream_merge() {
    local tmp="$TMP_DIR/stream.merge"
    jq -c --slurpfile st "$STREAM_STATE" '
      ($st[0]) as $s
      | reduce .[] as $d ($s;
          .finish = ($d.finish_reason // .finish)
          | .content += (($d.content // ""))
          | reduce (($d.tool_calls // [])[]) as $tc (.;
              (($tc.index // 0) | tostring) as $i
              | .tools[$i] = ((.tools[$i] // {"id":null,"name":null,"arguments":""})
                  | (if ($tc.id // null) != null then .id = $tc.id else . end)
                  | (if ($tc.function.name // null) != null then .name = $tc.function.name else . end)
                  | .arguments += (($tc.function.arguments) // "")) ))
    ' >"$tmp" 2>/dev/null && mv "$tmp" "$STREAM_STATE"
    STREAM_TEXT="$(jq -r '.content // ""' "$STREAM_STATE" 2>/dev/null)"
    STREAM_TOOLS="$(jq -r '.tools | length' "$STREAM_STATE" 2>/dev/null)"
    [ -z "$STREAM_TOOLS" ] && STREAM_TOOLS=0
}

# consume every complete SSE line that arrived since the last call
stream_pump() {   # $1 = 1 to render the accumulated text
    local total
    [ -s "$STREAM_FILE" ] || return 0
    total="$(wc -l <"$STREAM_FILE" 2>/dev/null)"
    [ "${total:-0}" -gt "$STREAM_LINES" ] || return 0
    sed -n "$((STREAM_LINES+1)),${total}p" "$STREAM_FILE" 2>/dev/null \
        | sed -n 's/^data: *//p' \
        | grep -v '^\[DONE\]' \
        | jq -sc '[.[] | (.choices[0].delta // empty)]' 2>/dev/null >"$TMP_DIR/stream.deltas"
    STREAM_LINES=$total
    [ -s "$TMP_DIR/stream.deltas" ] && stream_merge <"$TMP_DIR/stream.deltas"
    if [ "${1:-0}" = 1 ] && [ -n "$STREAM_TEXT" ]; then
        tg_view_text "$aid" "$answer" "$TRANSCRIPT_PRE$STREAM_TEXT"
        scroll_bottom
    fi
    return 0
}

# the assembled assistant message, ready to append to HISTORY
stream_finalize() {
    jq -c '
      {role:"assistant"}
      + (if (.content | length) > 0 then {content:.content} else {} end)
      + (if (.tools | length) > 0 then
           {tool_calls: [ .tools | to_entries[] | .value
              | {id:(.id // ""), type:"function",
                 function:{name:(.name // ""), arguments:(.arguments // "")}} ]}
         else {} end)
    ' "$STREAM_STATE" 2>/dev/null
}

# true when the response looks like SSE rather than a plain JSON object
stream_is_sse() { grep -q '^data: ' "$STREAM_FILE" 2>/dev/null; }

# POST with streaming: streams the reply into the answer view, then leaves the
# assembled message in STREAM_MSG. Returns 0=ok 1=error 2=cancelled.
STREAM_MSG=""
api_stream_post() {   # $1 = body
    local bodyf="$TMP_DIR/sbody.json" codef="$TMP_DIR/scode" errf="$TMP_DIR/serr" pid ec
    STREAM_MSG=""; API_RESP=""; CURL_ERR=""; HTTP_CODE=""
    POST_T0=$SECONDS; POST_LASTT=-1
    printf '%s' "$1" >"$bodyf"
    local attempt=0
    while :; do
        stream_reset
        curl -sS -N --max-time 240 "$API_URL" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            --data-binary @"$bodyf" -o "$STREAM_FILE" -w '%{http_code}' >"$codef" 2>"$errf" &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            busy_pump
            if [ "$CANCEL" = 1 ]; then
                kill "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                return 2
            fi
            stream_pump 1
            if [ $((SECONDS - POST_T0)) -ne "$POST_LASTT" ]; then
                POST_LASTT=$((SECONDS - POST_T0))
                [ -z "$STREAM_TEXT" ] && tg_view_text "$aid" "$send_btn" "Stop ${POST_LASTT}s"
            fi
            sleep 0.15
        done
        wait "$pid" 2>/dev/null; ec=$?
        stream_pump 0                       # drain what is left
        HTTP_CODE="$(cat "$codef" 2>/dev/null)"
        CURL_ERR="$(head -c 200 "$errf" 2>/dev/null | tr -d '\n')"
        # same policy as api_post: transient server-side failures get another
        # try (nothing was rendered yet, those replies are a JSON error, not SSE)
        case "$HTTP_CODE" in
            429|500|502|503|504)
                if [ "$attempt" -lt "$HTTP_RETRIES" ]; then
                    attempt=$((attempt+1))
                    toast "Retrying (HTTP $HTTP_CODE)…"
                    sleep "$attempt"
                    continue
                fi ;;
        esac
        break
    done
    if [ "$ec" -ne 0 ]; then
        [ -z "$CURL_ERR" ] && CURL_ERR="curl exit $ec"
        return 1
    fi
    if [ -n "$HTTP_CODE" ] && [ "$HTTP_CODE" -ge 400 ] 2>/dev/null; then
        CURL_ERR="HTTP $HTTP_CODE$( api_err_msg <"$STREAM_FILE")"
        return 1
    fi
    if ! stream_is_sse; then
        # the endpoint ignored stream:true — fall back to the plain object
        API_RESP="$(cat "$STREAM_FILE" 2>/dev/null)"
        return 0
    fi
    STREAM_MSG="$(stream_finalize)"
    return 0
}
# END STREAM BLOCK

# one-shot, no tools, no history — used by the clipboard quick-actions.
# Must be called in the main shell; the answer lands in ONESHOT_ANSWER.
ONESHOT_ANSWER=""
ai_oneshot() {   # $1 = prompt -> sets ONESHOT_ANSWER
    ONESHOT_ANSWER=""
    local body rc
    TRANSCRIPT_PRE="$TRANSCRIPT"
    # prompt via stdin: clipboard text can be arbitrarily large
    body="$(printf '%s' "$1" | jq -Rsc '[{role:"user",content:.}]' | json_body notools stream)"
    api_stream_post "$body"; rc=$?
    if [ "$rc" = 2 ]; then ONESHOT_ANSWER="(stopped)"; return 1; fi
    if [ "$rc" != 0 ]; then
        ONESHOT_ANSWER="Network error: ${CURL_ERR:-no response}"; return 1
    fi
    if stream_is_sse; then
        ONESHOT_ANSWER="$STREAM_TEXT"
        [ -z "$ONESHOT_ANSWER" ] && ONESHOT_ANSWER="No response."
        return 0
    fi
    if [ -z "$API_RESP" ]; then
        ONESHOT_ANSWER="Network error: ${CURL_ERR:-no response}"; return 1
    fi
    ONESHOT_ANSWER="$(jq -r '.choices[0].message.content // .error.message // "No response."' <<<"$API_RESP" 2>/dev/null)" \
        || ONESHOT_ANSWER="Unexpected API response."
}

# drop oldest turns (never the system prompt) until the serialized history fits
trim_history() {   # $1 = char budget
    local limit="$1"
    while [ ${#HISTORY} -gt "$limit" ] && [ "$(jq 'length' <<<"$HISTORY")" -gt 2 ]; do
        HISTORY="$(jq -c 'del(.[1])' <<<"$HISTORY")"
        # never leave orphaned tool results at the front — the API rejects them
        while [ "$(jq -r 'if length > 1 then .[1].role else "" end' <<<"$HISTORY")" = "tool" ]; do
            HISTORY="$(jq -c 'del(.[1])' <<<"$HISTORY")"
        done
    done
}

# ── Conversation persistence ─────────────────────────────────────────────────
# The history survives a restart; Reset clears it. Kept private (0600) because
# it contains everything the user asked and everything the model ran.
hist_save() {
    [ -n "${HISTORY:-}" ] || return 0
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    ( umask 077; printf '%s' "$HISTORY" >"$HIST_FILE" ) 2>/dev/null
}
hist_clear() {
    HISTORY='[]'
    rm -f "$HIST_FILE" 2>/dev/null
}
hist_load() {
    [ -s "$HIST_FILE" ] || return 0
    local h; h="$(cat "$HIST_FILE" 2>/dev/null)"
    jq -e 'type == "array" and length > 1' >/dev/null 2>&1 <<<"$h" || return 0
    HISTORY="$h"
    RESTORED_MSGS="$(jq 'length' <<<"$h")"
}

# agentic, multi-turn, with run_bash. Uses + updates the global HISTORY, and
# returns the final answer in the global AGENT_ANSWER. It must be called in the
# main shell (NOT via $(...)), otherwise HISTORY updates are lost to the subshell
# and conversation memory breaks.
HISTORY='[]'
RESTORED_MSGS=0; hist_load
AGENT_ANSWER=""
ai_agent() {   # $1 = user input -> sets AGENT_ANSWER
    AGENT_ANSWER=""
    local user="$1" run_start=$SECONDS
    if [ "$HISTORY" = '[]' ]; then
        HISTORY="$(jq -nc --arg s "$SYSTEM_PROMPT" '[{role:"system",content:$s}]')"
    fi
    trim_history "$HIST_LIMIT"
    HISTORY="$(jq -c --arg c "$user" '. + [{role:"user",content:$c}]' <<<"$HISTORY")"

    local i body resp err fr msg n j callid cargs cmd out toolmsg rc
    for ((i=0; i<MAX_ITERS; i++)); do
        if [ $((SECONDS - run_start)) -gt "$MAX_RUN_SECONDS" ]; then
            AGENT_ANSWER="(stopped: run budget of ${MAX_RUN_SECONDS}s exhausted)"
            hist_save
            return 1
        fi
        trim_history "$HIST_HARD_LIMIT"
        # history via stdin, not --argjson: it can exceed the per-argument limit
        body="$(json_body tools stream <<<"$HISTORY")"
        TRANSCRIPT_PRE="$TRANSCRIPT"      # live text renders on top of this
        api_stream_post "$body"; rc=$?
        [ "$rc" = 2 ] && { AGENT_ANSWER="(stopped)"; hist_save; return 1; }
        if [ "$rc" != 0 ]; then
            AGENT_ANSWER="Network error: ${CURL_ERR:-no response}"; hist_save; return 1
        fi
        if stream_is_sse; then
            msg="$STREAM_MSG"
            if [ -z "$msg" ]; then
                AGENT_ANSWER="Unexpected API response."; hist_save; return 1
            fi
            fr="$(jq -r 'if (.tool_calls // []) | length > 0 then "tool_calls" else "stop" end' <<<"$msg")"
            # never emit a message with neither content nor tool_calls: the API rejects it
            msg="$(jq -c 'if (has("content") or has("tool_calls")) then . else . + {content:""} end' <<<"$msg")"
        else
            resp="$API_RESP"
            if [ -z "$resp" ]; then
                AGENT_ANSWER="Network error: ${CURL_ERR:-no response}"; hist_save; return 1
            fi
            jq -e . >/dev/null 2>&1 <<<"$resp" || { AGENT_ANSWER="Unexpected API response."; hist_save; return 1; }
            err="$(api_err_msg <<<"$resp")"
            [ -n "$err" ] && { AGENT_ANSWER="API error: $err"; hist_save; return 1; }
            fr="$(jq -r '.choices[0].finish_reason // "stop"' <<<"$resp")"
            # strip reasoning_content; keep content+tool_calls
            msg="$(jq -c '.choices[0].message
                    | {role:"assistant", content:(.content // null), tool_calls:(.tool_calls // null)}
                    | with_entries(select(.value != null))
                    | if (has("content") or has("tool_calls")) then . else . + {content:""} end' <<<"$resp")"
        fi
        HISTORY="$(printf '%s\n%s\n' "$HISTORY" "$msg" | jq -cs '.[0] + [.[1]]')"

        if [ "$fr" = "tool_calls" ]; then
            n="$(jq '(.tool_calls // []) | length' <<<"$msg")"
            for ((j=0; j<n; j++)); do
                callid="$(jq -r ".tool_calls[$j].id" <<<"$msg")"
                cargs="$(jq -r ".tool_calls[$j].function.arguments" <<<"$msg")"
                cmd="$(jq -r '.command // empty' <<<"$cargs" 2>/dev/null)"
                if [ -z "$cmd" ]; then
                    # a reply cut off by max_tokens leaves the arguments unparseable;
                    # tell the model instead of silently running nothing (idea from
                    # antonum/bash-harness)
                    out="ERROR: tool call arguments were not valid JSON — the reply was probably cut off by max_tokens. Use shorter commands, e.g. write large files in several appends."
                elif [ "$CANCEL" = 1 ]; then
                    out="(stopped by user)"   # keep history valid: every call gets a reply
                else
                    transcript_add $'\n\n$ '"$cmd"
                    run_bash_tool "$cmd"
                    out="$TOOL_OUT"
                    transcript_add $'\n'"$out"
                fi
                toolmsg="$(jq -nc --arg id "$callid" --arg c "$out" \
                    '{role:"tool", tool_call_id:$id, content:$c}')"
                HISTORY="$(printf '%s\n%s\n' "$HISTORY" "$toolmsg" | jq -cs '.[0] + [.[1]]')"
            done
            [ "$CANCEL" = 1 ] && { AGENT_ANSWER="(stopped)"; return 1; }
            continue
        fi
        AGENT_ANSWER="$(jq -r '.content // ""' <<<"$msg")"
        [ -z "$AGENT_ANSWER" ] && AGENT_ANSWER="(no content)"
        hist_save
        return 0
    done
    AGENT_ANSWER="(stopped after $MAX_ITERS tool iterations)"
}

# the actual tool: run a command, capture everything, truncate.
# Output goes to a temp file, NOT $(...): command substitution waits for the
# pipe to close, so anything the command leaves running in the background
# (`foo &`, daemons) would hang the whole UI forever, even past the timeout.
TOOL_OUT=""
run_bash_tool() {   # $1 = command -> sets TOOL_OUT to "exit=N\n<output>"
    local cmd="$1" of="$TMP_DIR/tool.out" pid ec out
    TOOL_OUT="exit=0"
    [ -z "$cmd" ] && return
    # audit trail: every command the model runs, and when
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    printf '%s\t%s\n' "$(date '+%F %T')" "$cmd" >>"$CMD_LOG" 2>/dev/null
    # optional gate: risky commands wait for an explicit Run tap in the panel
    if [ "$CONFIRM_DANGEROUS" = 1 ] && printf '%s' "$cmd" | grep -Eq "$RISKY_PATTERN"; then
        PENDING=1; APPROVE=0
        tg_view_text "$aid" "$send_btn" "Run"
        transcript_add $'\n'"⚠ risky — tap Run to execute, Reset to skip"
        while [ "$PENDING" = 1 ] && [ "$APPROVE" = 0 ] && [ "$CANCEL" = 0 ]; do
            busy_pump
            sleep 0.15
        done
        PENDING=0
        tg_view_text "$aid" "$send_btn" "Stop"
        if [ "$APPROVE" != 1 ]; then
            TOOL_OUT="exit=126"$'\n'"(the user declined this command)"
            return
        fi
    fi
    ( cd "$HOME" && exec timeout -k 5 "$CMD_TIMEOUT" bash -c "$cmd" ) </dev/null >"$of" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        busy_pump
        if [ "$CANCEL" = 1 ]; then
            kill -TERM "$pid" 2>/dev/null   # timeout(1) forwards TERM to the command
            break
        fi
        sleep 0.2
    done
    wait "$pid" 2>/dev/null; ec=$?
    if [ "$CANCEL" = 1 ]; then
        TOOL_OUT="exit=130"$'\n'"(stopped by user)"
        return
    fi
    out="exit=$ec"$'\n'"$(cat "$of" 2>/dev/null)"
    if [ ${#out} -gt "$OUT_LIMIT" ]; then
        out="${out:0:$OUT_LIMIT}"$'\n...[truncated]'
    fi
    TOOL_OUT="$out"
}

# ── Overlay creation + permission check ──────────────────────────────────────
declare -A aparams=([$tgc_activity_overlay]="true")
tg_json_send newActivity aparams
_rec="$(tg_msg_recv)"
aid="$(echo "$_rec" | jq -r 'if type=="array" then .[0] else . end')"
if [ -z "$aid" ] || [ "$aid" = "-1" ] || [ "$aid" = "null" ]; then
    echo "Could not create the overlay window." >&2
    echo "Grant Termux:GUI the 'Display over other apps' permission, then rerun." >&2
    am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION -d package:com.termux.gui >/dev/null 2>&1
    exit 1
fi

# ── Colours ──────────────────────────────────────────────────────────────────
# setBackgroundColor only sets backgroundTintList (termux-gui 0.1.6
# HandleView.kt:482): it paints views that already HAVE a background drawable
# (Buttons; an EditText's underline) and is a no-op on LinearLayout / ScrollView
# / Space, which show the theme windowBackground the app puts on the root view.
# So: tint buttons and input underlines, and draw lines as text — hairline().
c_accent=ffe94560     # hot magenta — the mark and the primary action
c_bg=ff181a2f         # panel field (no visible effect, see above)
c_console=ff0e1020    # output console (no visible effect, see above)
c_btn=ff242a44        # neutral button surface
c_inputline=ff8a93b5  # input underline — must be light, it is the only outline
c_text=ffe8e8f0       # primary text
c_muted=ff8a93b5      # secondary text
c_white=ffffffff

# ── Build the UI ─────────────────────────────────────────────────────────────
declare -A rp=(); root="$(tg_create_linear "$aid" rp)"

# ── Sizing helper ────────────────────────────────────────────────────────────
# fixed(): give a view an EXACT size. termux-gui creates every LinearLayout
# child as LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, weight=1) plus
# MATCH_PARENT on the cross axis (0.1.6 Util.kt:140), so a width alone still
# stretches and weight 0 is mandatory. An exact height is what beats a Button's
# theme 88x48dp minWidth/minHeight: a fixed LayoutParams measures the child with
# an EXACTLY spec, and minimumHeight is ignored under EXACTLY.
fixed() {   # $1 id  $2 width dp  $3 height dp
    tg_view_width  "$aid" "$1" "$2"
    tg_view_height "$aid" "$1" "$3"
    tg_view_linear "$aid" "$1" 0
}

# Tiny bubble. It MUST be a Button: a Button consumes the touch so the overlay
# delivers the full down/move/up gesture (a TextView only yields "down", which
# breaks drag and tap-to-expand). Its click event is intentionally ignored —
# expand/collapse and drag are driven entirely by overlayTouch in handle_touch.
declare -A bubp=([$tgc_create_text]="⚡")
bubble="$(tg_create_button "$aid" bubp "$root")"
fixed "$bubble" 48 44
tg_view_text_size "$aid" "$bubble" 16
tg_view_padding   "$aid" "$bubble" 0
tg_view_bg_color  "$aid" "$bubble" "$c_accent"
tg_view_text_color "$aid" "$bubble" "$c_white"

# ── Panel sizing (every number is dp, not px) ────────────────────────────────
# The overlay window is WRAP_CONTENT, so a MATCH_PARENT child would expand it to
# full screen; everything inside gets fixed dp (screen here: 480dpi / 448dp
# wide) and the answer text a bounded width so it wraps instead of stretching.
# Vertical boxes (panel, setup_box, main_box) stay WRAP_CONTENT on purpose: a
# fixed height there hands spare space to every weight=1 child inside them.
PANEL_W=260
PAD=8
ROW_W=$((PANEL_W - 2*PAD))      # inner width that rows / buttons share
ANS_W=$((ROW_W - 8))            # answer text width (so it wraps)
ANS_H=180                       # console height

# Row heights and margins. PANEL_H_DP below is derived from these so a layout
# change cannot quietly leave it stale.
BTN_H=36        # every Button; an exact height is the only thing that wins over
                # the theme's 48dp minHeight
TITLE_H=38      # header row height = max(TITLE_H, mkicon 34 + 2*ROW_M)
IN_H=40         # input and Send
HAIR_H=12       # divider line (hairline()); also clips its wrapped second line
ROW_M=2         # margin on buttons / icons / console -> +2*ROW_M on that row
HAIR_M=4        # margin around the divider

DENSITY_DPI="$(/system/bin/getprop ro.sf.lcd_density 2>/dev/null)"
case "$DENSITY_DPI" in ''|*[!0-9]*) DENSITY_DPI=480 ;; esac
DENSITY_X=$((DENSITY_DPI / 160))     # dp -> px factor
[ "$DENSITY_X" -lt 1 ] && DENSITY_X=1
# CAVEAT: ro.sf.lcd_density (480 here) is not the density termux-gui converts dp
# with when a display-density override is active — measured 2.44 px/dp (the 260dp
# panel was 635px wide, i.e. 390dpi). So DENSITY_X can be ~20% too large, which
# only ever errs safe: it over-covers the drag clamps and the title-band hit test.

# Height the expanded panel occupies: padding + every row of main_box, the taller
# of the two boxes. panel_place() clamps the window with this, so it must never be
# less than the real height or the panel's bottom lands off-screen. Measured on
# this device (screencap): the panel occupied 935px = 384dp, so the sum below
# carries +8 for dp->px rounding.
PANEL_H_DP=$(( 8 + 2*PAD + TITLE_H + HAIR_H + 2*HAIR_M \
    + 2*(BTN_H + 2*ROW_M) + (IN_H + 2*ROW_M) + (ANS_H + 2*ROW_M) ))

# Panel (hidden until expanded)
declare -A pp=([$tgc_create_vertical]="true")
panel="$(tg_create_linear "$aid" pp "$root")"
tg_view_width    "$aid" "$panel" "$PANEL_W"
tg_view_bg_color "$aid" "$panel" "$c_bg"
tg_view_padding  "$aid" "$panel" "$PAD"
tg_view_vis      "$aid" "$panel" "$tgc_vis_gone"

mkbtn() {   # $1 parent  $2 text  [$3 textsize=12]  -> echoes id (styled, flat)
    declare -A _bp=([$tgc_create_text]="$2")
    local id; id="$(tg_create_button "$aid" _bp "$1")"
    tg_view_text_size "$aid" "$id" "${3:-12}"
    tg_view_height    "$aid" "$id" "$BTN_H"
    tg_view_padding   "$aid" "$id" 2          # default ~16dp side padding wrapped short labels
    tg_view_bg_color  "$aid" "$id" "$c_btn"
    tg_view_text_color "$aid" "$id" "$c_text"
    tg_view_margin    "$aid" "$id" "$ROW_M"
    echo "$id"
}
mkicon() {  # $1 parent  $2 glyph  -> small fixed-size flat icon button
    declare -A _ip=([$tgc_create_text]="$2")
    local id; id="$(tg_create_button "$aid" _ip "$1")"
    fixed "$id" 34 34          # weight 0: must not share spare width with the title
    tg_view_padding   "$aid" "$id" 0
    tg_view_text_size "$aid" "$id" 14
    tg_view_bg_color  "$aid" "$id" "$c_btn"
    tg_view_text_color "$aid" "$id" "$c_muted"
    tg_view_margin    "$aid" "$id" "$ROW_M"
    echo "$id"
}
hrow() {   # $1 parent -> echoes a fixed-width horizontal linear id
    declare -A _hp=([$tgc_create_vertical]="false")
    local id; id="$(tg_create_linear "$aid" _hp "$1")"
    tg_view_width "$aid" "$id" "$ROW_W"
    echo "$id"
}
hairline() {   # accent divider spanning the row. A Space has no background
               # drawable, so tg_view_bg_color on one tints nothing (that divider
               # was invisible); this is a TextView of box glyphs instead, with
               # more glyphs than fit so the line always spans the row and the
               # wrapped remainder gets clipped by the exact height.
    declare -A _dp=([$tgc_create_text]="────────────────────────────────────────────────────────────────────────────────")
    local id; id="$(tg_create_text "$aid" _dp "$1")"
    fixed "$id" "$ROW_W" "$HAIR_H"
    tg_view_padding    "$aid" "$id" 0
    tg_view_text_size  "$aid" "$id" 8
    tg_view_text_color "$aid" "$id" "$c_accent"
    tg_view_margin     "$aid" "$id" "$HAIR_M"
}
weigh() {  # give a view equal layout-weight so a row's buttons fill the width
    tg_view_width "$aid" "$1" 0
    tg_view_linear "$aid" "$1" 1
}

# ---- Settings box (first run, and the ⚙ button): provider, key, model ----
declare -A setp=([$tgc_create_vertical]="true")
setup_box="$(tg_create_linear "$aid" setp "$panel")"
tg_view_width "$aid" "$setup_box" "$ROW_W"
prov_btn="$(mkbtn "$setup_box" "Provider: $PROVIDER_LABEL ▸" 12)"
tg_view_width "$aid" "$prov_btn" "$ROW_W"
declare -A slp=([$tgc_create_text]="$PROVIDER_LABEL API key:")
setup_lbl="$(tg_create_text "$aid" slp "$setup_box")"
tg_view_text_color "$aid" "$setup_lbl" "$c_text"
tg_view_text_size  "$aid" "$setup_lbl" 12
declare -A skp=([$tgc_create_text]="" [$tgc_create_type]="textPassword" [$tgc_create_single_line]="true")
setup_input="$(tg_create_edit "$aid" skp "$setup_box")"
tg_view_width "$aid" "$setup_input" "$ROW_W"
tg_view_text_color "$aid" "$setup_input" "$c_text"
tg_view_bg_color   "$aid" "$setup_input" "$c_inputline"   # visible underline
declare -A mlp=([$tgc_create_text]="Model (type any id, or tap Models):")
model_lbl="$(tg_create_text "$aid" mlp "$setup_box")"
tg_view_text_color "$aid" "$model_lbl" "$c_text"
tg_view_text_size  "$aid" "$model_lbl" 12
declare -A mdp=([$tgc_create_text]="$ACTIVE_MODEL" [$tgc_create_single_line]="true")
model_input="$(tg_create_edit "$aid" mdp "$setup_box")"
tg_view_width "$aid" "$model_input" "$ROW_W"
tg_view_text_color "$aid" "$model_input" "$c_text"
tg_view_bg_color   "$aid" "$model_input" "$c_inputline"
setup_row="$(hrow "$setup_box")"
setup_paste="$(mkbtn "$setup_row" "Paste key")"; weigh "$setup_paste"
setup_models="$(mkbtn "$setup_row" "Models")"; weigh "$setup_models"
setup_row2="$(hrow "$setup_box")"
setup_save="$(mkbtn "$setup_row2" "Save")"; weigh "$setup_save"
setup_cancel="$(mkbtn "$setup_row2" "Cancel")"; weigh "$setup_cancel"

# ---- Main box (normal operation) ----
declare -A mbp=([$tgc_create_vertical]="true")
main_box="$(tg_create_linear "$aid" mbp "$panel")"
tg_view_width "$aid" "$main_box" "$ROW_W"

# header row: accent mark + title (left), small icon buttons (right)
title_row="$(hrow "$main_box")"
declare -A tlp=([$tgc_create_text]="⚡ $PROVIDER_LABEL")
title="$(tg_create_text "$aid" tlp "$title_row")"
tg_view_text_color "$aid" "$title" "$c_accent"
tg_view_text_size  "$aid" "$title" 15
tg_view_gravity    "$aid" "$title" "$tgc_grav_top_left" "$tgc_grav_center"
tg_view_width "$aid" "$title" 0; tg_view_linear "$aid" "$title" 1
tg_view_height "$aid" "$title" "$TITLE_H"      # = the icon row height, so text centres
tg_view_padding "$aid" "$title" 4 "$tgc_dir_left"
close_btn="$(mkicon "$title_row" "▽")"
quit_btn="$(mkicon  "$title_row" "✕")"
model_btn="$(mkicon "$title_row" "⚙")"
hairline "$main_box"

# clipboard action toolbar (acts on the currently-copied text) — smaller text fits
act_row="$(hrow "$main_box")"
act_tr="$(mkbtn "$act_row" "Trans" 11)";  weigh "$act_tr"
act_sum="$(mkbtn "$act_row" "Sum" 11)";   weigh "$act_sum"
act_exp="$(mkbtn "$act_row" "Expl" 11)";  weigh "$act_exp"
act_fix="$(mkbtn "$act_row" "Fix" 11)";   weigh "$act_fix"
act_reply="$(mkbtn "$act_row" "Reply" 11)"; weigh "$act_reply"

# input row: a visible input well + a compact accent Send
in_row="$(hrow "$main_box")"
declare -A inp=([$tgc_create_text]="" [$tgc_create_single_line]="true")
input="$(tg_create_edit "$aid" inp "$in_row")"
tg_view_width "$aid" "$input" 0; tg_view_linear "$aid" "$input" 1
tg_view_height     "$aid" "$input" "$IN_H"
tg_view_bg_color   "$aid" "$input" "$c_inputline"   # tints the underline
tg_view_text_color "$aid" "$input" "$c_text"
tg_view_text_size  "$aid" "$input" 14
tg_view_padding    "$aid" "$input" 8
tg_view_margin     "$aid" "$input" "$ROW_M"
send_btn="$(mkbtn "$in_row" "Send" 13)"
fixed "$send_btn" 64 "$IN_H"   # weight 0, or it eats the input's width
tg_view_bg_color "$aid" "$send_btn" "$c_accent"
tg_view_text_color "$aid" "$send_btn" "$c_white"

# controls row — weighted to fill width
ctl_row="$(hrow "$main_box")"
copy_btn="$(mkbtn  "$ctl_row" "Copy")";  weigh "$copy_btn"
speak_btn="$(mkbtn "$ctl_row" "Speak")"; weigh "$speak_btn"
reset_btn="$(mkbtn "$ctl_row" "Reset")"; weigh "$reset_btn"
mic_btn="$(mkbtn "$ctl_row" "Mic")";   weigh "$mic_btn"

# answer console (scrollable) — distinct dark surface, last
declare -A scp=()
scroll="$(tg_create_nested_scroll "$aid" scp "$main_box")"
tg_view_width   "$aid" "$scroll" "$ROW_W"
tg_view_height  "$aid" "$scroll" "$ANS_H"
tg_view_bg_color "$aid" "$scroll" "$c_console"
tg_view_margin  "$aid" "$scroll" "$ROW_M"
declare -A anp=([$tgc_create_text]="› Copy text + tap an action, or type a request. I can run commands on your device." [$tgc_create_selectable_text]="true")
answer="$(tg_create_text "$aid" anp "$scroll")"
tg_view_width "$aid" "$answer" "$ANS_W"     # bounded so the text wraps
tg_view_text_size  "$aid" "$answer" 13
tg_view_padding    "$aid" "$answer" 8
tg_view_text_color "$aid" "$answer" "$c_text"

# ── Transcript management ────────────────────────────────────────────────────
TRANSCRIPT="› Copy text + tap an action, or type a request. I can run commands on your device."
LAST_ANSWER=""
# tg_str_quote can only escape \n and \t — any other control byte (a stray \r,
# ANSI escapes, or a literal RS, which is the protocol delimiter!) would produce
# a broken setText message. Strip them before anything reaches the screen.
transcript_clean() { printf '%s' "$1" | tr -d '\000-\010\013-\037\177'; }
# scroll the console to the newest line after an update (a huge y is clamped by
# the ScrollView); the getter is avoided because it can block
scroll_bottom() { tg_view_set_scroll "$aid" "$scroll" 0 999999 2>/dev/null; }
transcript_set() { TRANSCRIPT="$(transcript_clean "$1")"; tg_view_text "$aid" "$answer" "$TRANSCRIPT"; scroll_bottom; }
transcript_add() {
    TRANSCRIPT="$TRANSCRIPT$(transcript_clean "$1")"
    # cap it: every update re-sends the whole text, so an unbounded transcript
    # makes the UI progressively slower
    if [ ${#TRANSCRIPT} -gt "$TRANS_LIMIT" ]; then
        TRANSCRIPT="…${TRANSCRIPT: -$TRANS_LIMIT}"
    fi
    tg_view_text "$aid" "$answer" "$TRANSCRIPT"
    scroll_bottom
}

[ "$RESTORED_MSGS" -gt 1 ] && transcript_set "› Restored $((RESTORED_MSGS-1)) messages from the last session.
$TRANSCRIPT"

# ── Setup / main toggling ────────────────────────────────────────────────────
SETUP_ORIG=""; SETUP_ORIG_MODEL=""
MODEL_LIST=(); MODEL_IDX=0

refresh_setup() {   # push the current provider / model into the settings widgets
    local kv; kv="$(provider_keyvar "$PROVIDER")"
    tg_view_text "$aid" "$prov_btn" "Provider: $PROVIDER_LABEL ▸"
    if [ "$PROVIDER" = ollama ]; then
        tg_view_text "$aid" "$setup_lbl" "Ollama: no key needed"
    elif [ -n "${KEYS[$kv]:-}" ]; then
        tg_view_text "$aid" "$setup_lbl" "$PROVIDER_LABEL key (empty = keep saved):"
    else
        tg_view_text "$aid" "$setup_lbl" "$PROVIDER_LABEL API key:"
    fi
    tg_view_text "$aid" "$setup_input" ""
    tg_view_text "$aid" "$model_input" "$ACTIVE_MODEL"
    tg_view_text "$aid" "$title" "⚡ $PROVIDER_LABEL"
    MODEL_LIST=(); MODEL_IDX=0
}
show_setup() {
    SETUP_ORIG="$PROVIDER"; SETUP_ORIG_MODEL="$ACTIVE_MODEL"
    refresh_setup
    tg_view_vis "$aid" "$setup_box" "$tgc_vis_visible"
    tg_view_vis "$aid" "$main_box"  "$tgc_vis_gone"
}
show_main() {
    tg_view_text "$aid" "$title" "⚡ $PROVIDER_LABEL"
    tg_view_vis "$aid" "$setup_box" "$tgc_vis_gone"
    tg_view_vis "$aid" "$main_box"  "$tgc_vis_visible"
}

# Provider button: remember what was typed, then move to the next provider
setup_cycle_provider() {
    local p next="" first="" cur=0 i=0 list="" m
    get_text "$model_input"; m="${REPLY//[$'\n\r\t ']/}"
    [ -n "$m" ] && MODELS[$PROVIDER]="$m"
    for p in $KNOWN_PROVIDERS; do
        [ "$p" = custom ] && [ -z "$CUSTOM_URL" ] && continue
        list="$list $p"
    done
    for p in $list; do
        i=$((i+1)); [ -z "$first" ] && first="$p"
        [ "$p" = "$PROVIDER" ] && cur=$i
    done
    i=0
    for p in $list; do i=$((i+1)); [ "$i" -gt "$cur" ] && { next="$p"; break; }; done
    [ -z "$next" ] && next="$first"
    activate_provider "$next"
    PROVIDER_LABEL="$(provider_label "$PROVIDER")"
    refresh_setup
}

# Models button: fetch the provider's model list once, then each tap fills in the next id
models_action() {
    local url key list hdr=()
    if [ "${#MODEL_LIST[@]}" -eq 0 ]; then
        url="${API_URL%/chat/completions}/models"
        get_text "$setup_input"; key="${REPLY//[$'\n\r\t ']/}"
        [ -z "$key" ] && key="$API_KEY"
        if [ -z "$key" ]; then toast "Enter your key first, then tap Models"; return; fi
        toast "Loading models…"
        hdr=(-H "Authorization: Bearer $key")
        [ "$PROVIDER" = claude ] && hdr+=(-H "x-api-key: $key" -H "anthropic-version: 2023-06-01")
        list="$(timeout 20 curl -sS --max-time 15 "${hdr[@]}" "$url" 2>/dev/null \
            | jq -r '(.data // .models // [])[] | (.id // .name // empty)' 2>/dev/null \
            | sed 's#^models/##' \
            | grep -viE 'embed|whisper|tts|dall-e|moderation|transcribe|realtime|audio|image|guard|deep-research|computer-use|robotics|antigravity|live|lyria|nano-banana|omni|aqa|gemma' \
            | sort -u)"
        if [ -z "$list" ]; then toast "Could not load models. Type the model id yourself."; return; fi
        mapfile -t MODEL_LIST <<<"$list"
        MODEL_IDX=0
    else
        MODEL_IDX=$(( (MODEL_IDX + 1) % ${#MODEL_LIST[@]} ))
    fi
    tg_view_text "$aid" "$model_input" "${MODEL_LIST[$MODEL_IDX]}"
    toast "$((MODEL_IDX+1))/${#MODEL_LIST[@]}: ${MODEL_LIST[$MODEL_IDX]}"
}

setup_cancel_action() {
    if [ "$SETUP_ORIG" != ollama ] && [ -z "${KEYS[$(provider_keyvar "$SETUP_ORIG")]:-}" ]; then
        toast "Add a key first"; return
    fi
    MODELS[$SETUP_ORIG]="$SETUP_ORIG_MODEL"
    activate_provider "$SETUP_ORIG"
    PROVIDER_LABEL="$(provider_label "$PROVIDER")"
    show_main
}

save_key() {
    local k m old_key="$API_KEY" old_model="$ACTIVE_MODEL" rc err=""
    get_text "$setup_input"; k="${REPLY//[$'\n\r\t ']/}"
    get_text "$model_input"; m="${REPLY//[$'\n\r\t ']/}"
    [ -z "$m" ] && m="$(provider_model "$PROVIDER")"
    [ -z "$m" ] && { toast "Enter a model id"; return; }
    [ -z "$k" ] && k="$API_KEY"          # empty field = keep the saved key
    [ -z "$k" ] && { toast "Enter a key first"; return; }
    API_KEY="$k"; ACTIVE_MODEL="$m"
    toast "Checking…"
    busy_begin
    api_post "$(jq -nc --arg m "$ACTIVE_MODEL" --arg tf "$TOKEN_FIELD" '{model:$m,messages:[{role:"user",content:"hi"}]} + {($tf):16}')"
    rc=$?
    busy_end
    [ -n "$API_RESP" ] && err="$(api_err_msg <<<"$API_RESP")"
    if [ "$rc" -ne 0 ] || [ -z "$API_RESP" ] || [ -n "$err" ]; then
        API_KEY="$old_key"; ACTIVE_MODEL="$old_model"
        toast "Failed: ${err:-${CURL_ERR:-no response}}"
        return
    fi
    save_config
    toast "$PROVIDER_LABEL · $ACTIVE_MODEL saved ✓"
    show_main
}

# ── Expand / collapse ────────────────────────────────────────────────────────
expanded=0
# Touch reporting stays enabled while the panel is open: the panel is dragged by
# its title band (see handle_touch), and the per-sample cost is ~0.27 ms thanks
# to the fork-free event path. Turning it off would make the panel immovable.
# Learn the screen extent from real touches — getConfiguration never answers, so
# a conservative bound from the fingers we have seen is better than none.
panel_place() {
    local ph=$((PANEL_H_DP * DENSITY_X)) pw=$((PANEL_W * DENSITY_X)) moved=0
    if [ "$SCREEN_H_PX" -gt 0 ] && [ "$posY" -gt $((SCREEN_H_PX - ph)) ]; then
        posY=$((SCREEN_H_PX - ph)); moved=1
    fi
    if [ "$SCREEN_W_PX" -gt 0 ] && [ "$posX" -gt $((SCREEN_W_PX - pw)) ]; then
        posX=$((SCREEN_W_PX - pw)); moved=1
    fi
    [ "$posY" -lt 0 ] && posY=0
    [ "$posX" -lt 0 ] && posX=0
    [ "$moved" = 1 ] && tg_activity_position "$aid" "$posX" "$posY"
}
expand()   { expanded=1; panel_place; tg_view_vis "$aid" "$bubble" "$tgc_vis_gone"; tg_view_vis "$aid" "$panel" "$tgc_vis_visible"; }
collapse() { expanded=0; tg_view_vis "$aid" "$panel" "$tgc_vis_gone"; tg_view_vis "$aid" "$bubble" "$tgc_vis_visible"; }

# ── Actions ──────────────────────────────────────────────────────────────────
clip_action() {   # $1 = instruction
    local text
    text="$(termux-clipboard-get 2>/dev/null)"
    if [ -z "$text" ]; then transcript_add $'\n\n(clipboard is empty)'; return; fi
    transcript_add $'\n\n▸ '"$1"$'\n⏳ …'
    busy_begin
    ai_oneshot "$1"$':\n\n'"$text"     # main-context call: sets ONESHOT_ANSWER
    busy_end
    LAST_ANSWER="$ONESHOT_ANSWER"
    transcript_add $'\n'"$ONESHOT_ANSWER"
}

do_send() {
    get_text "$input"; local q="$REPLY"
    [ -z "$q" ] && return
    tg_view_text "$aid" "$input" ""
    transcript_add $'\n\n🧑 '"$q"$'\n⏳ …'
    busy_begin
    ai_agent "$q"            # main-context call so HISTORY persists across turns
    busy_end
    hist_save                # survive a restart
    LAST_ANSWER="$AGENT_ANSWER"
    transcript_add $'\n\n🤖 '"$AGENT_ANSWER"
}

SCREEN_W_PX=0; SCREEN_H_PX=0   # must exist before the first panel_place (set -u)

# ── Start in the right mode ──────────────────────────────────────────────────
if [ -z "$API_KEY" ]; then
    expand; show_setup
else
    show_main
fi

# enable overlay touch events (no binding exists → raw method) and place bubble
declare -A _otp=([aid]="$aid" [send]="true")
tg_json_send sendOverlayTouchEvent _otp
posX=40; posY=600
tg_activity_position "$aid" "$posX" "$posY"

# ── Screen bounds (so the bubble can't be dragged off-screen) ────────────────
update_screen_bounds() {
    # getConfiguration is not answered by this Termux:GUI build, and the timed
    # read could swallow a pending reply, so screen bounds are learned from real
    # touches instead (see touch_apply / panel_place). Hook kept for the config
    # event: nothing to do.
    :
}
update_screen_bounds

# ── Event plumbing (fork-free) ───────────────────────────────────────────────
# tg_event_type/tg_event_id spawn a jq process per event. On a drag that is one
# fork per touch sample — the main reason the bubble felt sluggish. Everything
# below the socket read is regex on the string we already have.
EV=""; EV_TYPE=""; EV_ID=""; _ev_probe=""
ev_parse() {   # $1 = raw event JSON -> sets EV_TYPE, and EV_ID for clicks
    EV="$1"; EV_TYPE=""; EV_ID=""
    [[ $EV =~ \"type\":\"([A-Za-z_]+)\" ]] && EV_TYPE=${BASH_REMATCH[1]}
    [ "$EV_TYPE" = "click" ] && [[ $EV =~ \"id\":([0-9]+) ]] && EV_ID=${BASH_REMATCH[1]}
}
ev_ready() {   # probe only: succeeds when an event is queued, consumes nothing
    IFS= read -t 0 -r -s -d $'\x1e' -u "${tg__event[0]}" _ev_probe
}
recv_ev() {    # blocking read straight into EV (no $(...) → no subshell per event)
    IFS= read -r -s -d $'\x1e' -u "${tg__event[0]}" EV
}

# ── Drag handling (collapsed only) ───────────────────────────────────────────
dsx=0; dsy=0; spx=0; spy=0; moved=0; LSPX=-1; LSPY=-1; PANEL_DRAG=0
send_pos() {   # one setPosition per batch, and only when the position changed
    if [ "$posX" != "$LSPX" ] || [ "$posY" != "$LSPY" ]; then
        LSPX=$posX; LSPY=$posY
        tg_activity_position "$aid" "$posX" "$posY"
    fi
}
clamp_pos() {
    [ "$posX" -lt 0 ] && posX=0
    [ "$posY" -lt 0 ] && posY=0
    if [ "$SCREEN_W_PX" -gt "$EDGE_KEEP" ]; then
        [ "$posX" -gt "$((SCREEN_W_PX - EDGE_KEEP))" ] && posX=$((SCREEN_W_PX - EDGE_KEEP))
        [ "$posY" -gt "$((SCREEN_H_PX - EDGE_KEEP))" ] && posY=$((SCREEN_H_PX - EDGE_KEEP))
    fi
}
touch_apply() {   # $1=x $2=y $3=action — apply one touch sample
    local x="$1" y="$2" a="$3" dx dy adx ady
    # learn the screen extent (getConfiguration is unanswered on this build)
    [ "$x" -gt "$SCREEN_W_PX" ] && SCREEN_W_PX=$x
    [ "$y" -gt "$SCREEN_H_PX" ] && SCREEN_H_PX=$y
    case "$a" in
        down) dsx=$x; dsy=$y; spx=$posX; spy=$posY; moved=0 ;;
        move)
            dx=$((x-dsx)); dy=$((y-dsy))
            adx=${dx#-}; ady=${dy#-}
            { [ "$adx" -gt 15 ] || [ "$ady" -gt 15 ]; } && moved=1
            [ "$expanded" = 1 ] && [ "$moved" = 0 ] && return
            posX=$((spx+dx)); posY=$((spy+dy))
            clamp_pos
            send_pos
            ;;
        up)
            dx=$((x-dsx)); dy=$((y-dsy))
            if [ "$expanded" = 0 ] || [ "$moved" = 1 ]; then
                posX=$((spx+dx)); posY=$((spy+dy))
                clamp_pos
                send_pos
            fi
            [ "$moved" = 0 ] && [ "$expanded" = 0 ] && expand
            PANEL_DRAG=0
            ;;
    esac
}
handle_touch() {   # $1 = raw event JSON (regex only: hot path)
    local ev="$1" x=0 y=0 a="" a2="" lx ly la drained=0
    # the app reports touches as floats ("x":164.00879) — keep the integer part
    [[ $ev =~ \"x\":(-?[0-9]+)(\.[0-9]+)? ]] && x=${BASH_REMATCH[1]}
    [[ $ev =~ \"y\":(-?[0-9]+)(\.[0-9]+)? ]] && y=${BASH_REMATCH[1]}
    [[ $ev =~ \"action\":\"([a-z_]+)\" ]] && a=${BASH_REMATCH[1]}
    # Collapsed: the whole bubble drags. Expanded: only a gesture that starts in
    # the panel's title band moves the window, so the text stays scrollable.
    if [ "$expanded" = 1 ]; then
        if [ "$a" = "down" ]; then
            local band rel
            band=$((52 * DENSITY_X + DRAG_EXTRA_PX)); rel=$((y - posY))
            # accept both coordinate styles: screen-absolute (rel) and window-relative (y)
            if { [ "$rel" -ge 0 ] && [ "$rel" -le "$band" ]; } || { [ "$y" -ge 0 ] && [ "$y" -le "$band" ]; }; then
                PANEL_DRAG=1
            else
                PANEL_DRAG=0
            fi
            [ "${DRAG_DEBUG:-0}" = 1 ] && printf '%s down y=%s posY=%s band=%s drag=%s\n' "$(date +%T)" "$y" "$posY" "$band" "$PANEL_DRAG" >>"$CONFIG_DIR/touch.log" 2>/dev/null
        fi
        [ "${PANEL_DRAG:-0}" = 1 ] || return
    fi
    touch_apply "$x" "$y" "$a"

    # Coalesce the burst the app queued while we were busy: apply only the newest
    # sample so the bubble tracks the finger instead of replaying a backlog.
    lx=$x; ly=$y; la=$a
    while [ "$drained" -lt 60 ] && ev_ready; do
        drained=$((drained+1))
        recv_ev || break
        if [[ $EV =~ \"action\":\"([a-z_]+)\" ]]; then
            a2=${BASH_REMATCH[1]}
            [[ $EV =~ \"x\":(-?[0-9]+)(\.[0-9]+)? ]] && lx=${BASH_REMATCH[1]}
            [[ $EV =~ \"y\":(-?[0-9]+)(\.[0-9]+)? ]] && ly=${BASH_REMATCH[1]}
            la=$a2
        else
            ev_parse "$EV"
            case "$EV_TYPE" in
                click)   handle_click "$EV_ID" ;;
                destroy) exit 0 ;;
                config)  update_screen_bounds ;;
            esac
        fi
    done
    [ "$drained" -gt 0 ] && touch_apply "$lx" "$ly" "$la"
}

# ── Click handling (shared by the event loop and the busy pump) ──────────────
handle_click() {   # $1 = view id
    local id="$1"
    # while a request/tool run is in flight only these clicks make sense; anything
    # else would nest another API call inside the running one
    if [ "$BUSY" = 1 ]; then
        case "$id" in
            "$send_btn")  if [ "$PENDING" = 1 ]; then APPROVE=1; else CANCEL=1; toast "Stopping…"; fi; return ;;
            "$reset_btn") if [ "$PENDING" = 1 ]; then APPROVE=-1; else CANCEL=1; toast "Stopping…"; fi; return ;;
            "$quit_btn"|"$close_btn"|"$copy_btn"|"$speak_btn") ;;
            *) return ;;
        esac
    fi
    case "$id" in
        "$close_btn") collapse ;;
        "$quit_btn")  tg_activity_finish "$aid"; exit 0 ;;
        "$send_btn")  do_send ;;
        "$reset_btn") hist_clear; transcript_set "Conversation reset." ;;
        "$model_btn") show_setup ;;
        "$mic_btn")
            transcript_add $'\n'"🎤 listening…"
            local raw spk
            raw="$(timeout 45 termux-speech-to-text 2>/dev/null)"
            spk="$(printf '%s' "$raw" | jq -r 'if type == "object" then (.text // empty) else . end' 2>/dev/null)"
            [ -z "$spk" ] && spk="$raw"
            if [ -n "$spk" ]; then
                tg_view_text "$aid" "$input" "$spk"
                transcript_add $'\n'"🎤 $spk"
            else
                transcript_add $'\n'"🎤 (nothing recognised)"
            fi
            ;;
        "$copy_btn")  [ -n "$LAST_ANSWER" ] && { printf '%s' "$LAST_ANSWER" | termux-clipboard-set 2>/dev/null; toast "Copied"; } ;;
        "$speak_btn") [ -n "$LAST_ANSWER" ] && termux-tts-speak "$LAST_ANSWER" >/dev/null 2>&1 & ;;
        "$setup_paste") tg_view_text "$aid" "$setup_input" "$(termux-clipboard-get 2>/dev/null)" ;;
        "$setup_save")  save_key ;;
        "$setup_cancel") setup_cancel_action ;;
        "$setup_models") models_action ;;
        "$prov_btn")    setup_cycle_provider ;;
        "$act_tr")    clip_action "Translate the following text to English (or to the user's language if it is already English). Output only the translation" ;;
        "$act_sum")   clip_action "Summarize the following text in a few bullet points" ;;
        "$act_exp")   clip_action "Explain the following clearly and simply" ;;
        "$act_fix")   clip_action "Fix the spelling and grammar of the following text. Output only the corrected text" ;;
        "$act_reply") clip_action "Write a friendly, appropriate reply to the following message" ;;
    esac
}
handle_event() {   # $1 = raw event JSON
    ev_parse "$1"
    case "$EV_TYPE" in
        destroy) exit 0 ;;                 # activity killed → don't linger as an orphan
        config)  update_screen_bounds ;;    # rotation etc. changes the clamp box
        overlayTouch) handle_touch "$1" ;;
        click)   handle_click "$EV_ID" ;;
    esac
}

# ── Event loop ───────────────────────────────────────────────────────────────
while recv_ev; do
    handle_event "$EV"
done
exit 0
