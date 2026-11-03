#!/data/data/com.termux/files/usr/bin/bash
set -u

# deepseek-chat.sh — chat with the same AI (and the same agent tool run_bash)
# directly in the Termux terminal. No GUI needed. Shares provider/key/model
# with deepseek-bubble.sh via ~/.config/deepseek-bubble/config.
#
#   ./deepseek-chat.sh                      interactive chat
#   ./deepseek-chat.sh "your question"      one-shot answer
#   cat file.txt | ./deepseek-chat.sh "summarize this"
#   ./deepseek-chat.sh --provider openai --model gpt-4o-mini
#
# In chat: /help /reset /model [id] /provider [name] /confirm on|off /exit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
CLI_PROVIDER=""; CLI_MODEL=""; NEW=0; ARGS=()

usage() {
    cat <<'HELP'
Usage: deepseek-chat.sh [--provider NAME] [--model ID] [--new] [text...]
  no text, terminal   interactive chat (history kept between runs)
  text or piped stdin one-shot answer, then exit
  --new               start with an empty conversation
Providers: deepseek openai gemini claude openrouter groq ollama custom
Chat commands: /help /reset /model [id] /provider [name] /confirm on|off /exit
HELP
}
while [ $# -gt 0 ]; do
    case "$1" in
        --provider) CLI_PROVIDER="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        --model)    CLI_MODEL="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        --new)      NEW=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; ARGS+=("$@"); break ;;
        -*)         echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
        *)          ARGS+=("$1"); shift ;;
    esac
done

for _dep in curl jq timeout sed grep; do
    command -v "$_dep" >/dev/null 2>&1 || {
        echo "Missing dependency: $_dep — run: pkg install curl jq coreutils" >&2; exit 1; }
done

# ── Colours (only on a terminal) ─────────────────────────────────────────────
if [ -t 1 ]; then
    C_ACC=$'\e[38;5;204m'; C_DIM=$'\e[2m'; C_ERR=$'\e[31m'; C_RST=$'\e[0m'
else
    C_ACC=""; C_DIM=""; C_ERR=""; C_RST=""
fi

# ── Providers (same presets as the bubble) ───────────────────────────────────
KNOWN_PROVIDERS="deepseek openai gemini claude openrouter groq ollama custom"
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
provider_keyvar() {
    case "$1" in
        deepseek) echo DEEPSEEK_API_KEY ;; openai) echo OPENAI_API_KEY ;;
        gemini) echo GEMINI_API_KEY ;; claude) echo ANTHROPIC_API_KEY ;;
        openrouter) echo OPENROUTER_API_KEY ;; groq) echo GROQ_API_KEY ;;
        ollama) echo OLLAMA_API_KEY ;; *) echo AI_API_KEY ;;
    esac
}

# ── Settings ─────────────────────────────────────────────────────────────────
CONFIG_DIR="${AI_CONFIG_DIR:-$HOME/.config/deepseek-bubble}"
CONFIG_FILE="$CONFIG_DIR/config"
HIST_FILE="$CONFIG_DIR/history-cli.json"   # separate from the bubble's history
CMD_LOG="$CONFIG_DIR/cmd.log"
MAX_TOKENS=8000; THINKING=off; CONFIRM_DANGEROUS=0
MAX_ITERS=25; CMD_TIMEOUT=120; OUT_LIMIT=10000; HIST_LIMIT=60000; HIST_HARD_LIMIT=240000
HTTP_RETRIES=2
RISKY_PATTERN='(^|[;&|(]|&&|\|\|)[[:space:]]*(rm|rmdir|shred|mkfs|dd|truncate|mv|chmod|chown|pm[[:space:]]+(un)?install|am[[:space:]]+force-stop|settings[[:space:]]+put|reboot|svc[[:space:]]|cmd[[:space:]]|termux-clipboard-set)'

SYSTEM_PROMPT="You are a helpful assistant in the user's Termux terminal on an Android phone (Bionic libc, no sudo/root). You can run bash commands on the device with the run_bash tool to inspect files, run programs, fetch things, and get tasks done. Prefer doing the work with tools over describing it. Keep answers concise and readable on a small screen."
TOOLS='[{"type":"function","function":{"name":"run_bash","description":"Run a bash command on the Android/Termux device and return combined stdout+stderr plus the exit code.","parameters":{"type":"object","properties":{"command":{"type":"string","description":"The bash command to run."}},"required":["command"]}}}]'

PROVIDER="${AI_PROVIDER:-deepseek}"
API_URL=""; MODEL=""; API_KEY=""; TOKEN_FIELD="max_tokens"
declare -A KEYS=(); declare -A MODELS=()
CUSTOM_URL="${AI_BASE_URL:-}"

activate_provider() {
    local p="$1" kv
    PROVIDER="$p"
    API_URL="$(provider_url "$p")"
    [ "$p" = custom ] && [ -n "$CUSTOM_URL" ] && API_URL="$CUSTOM_URL"
    MODEL="${MODELS[$p]:-$(provider_model "$p")}"
    kv="$(provider_keyvar "$p")"
    API_KEY="${KEYS[$kv]:-}"
    [ "$p" = ollama ] && [ -z "$API_KEY" ] && API_KEY="ollama"
    if [ "$p" = openai ]; then TOKEN_FIELD="max_completion_tokens"; else TOKEN_FIELD="max_tokens"; fi
}

load_config() {
    local line v k kv cfg_provider="" cfg_model="" cfg_url=""
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            v="${line#*=}"
            case "$line" in
                AI_PROVIDER=*)         cfg_provider="$v" ;;
                AI_MODEL=*)            cfg_model="$v" ;;
                AI_BASE_URL=*)         CUSTOM_URL="${CUSTOM_URL:-$v}" ;;
                DEEPSEEK_MODEL=*)      [ -n "$v" ] && MODELS[deepseek]="$v" ;;
                DEEPSEEK_API_URL=*)    cfg_url="$v" ;;
                DEEPSEEK_MAX_TOKENS=*) [ -n "$v" ] && MAX_TOKENS="$v" ;;
                DEEPSEEK_THINKING=*)   [ -n "$v" ] && THINKING="$v" ;;
                BASH_CONFIRM=*)        [ -n "$v" ] && CONFIRM_DANGEROUS="$v" ;;
                MODEL_*=*)             k="${line%%=*}"; k="${k#MODEL_}"; [ -n "$v" ] && MODELS[$k]="$v" ;;
                *_API_KEY=*)           k="${line%%=*}"; [ -n "$v" ] && KEYS[$k]="$v" ;;
            esac
        done < "$CONFIG_FILE"
    fi
    for k in $KNOWN_PROVIDERS; do
        kv="$(provider_keyvar "$k")"
        [ -n "${!kv:-}" ] && KEYS[$kv]="${!kv}"
    done
    [ -z "${AI_PROVIDER:-}" ] && [ -n "$cfg_provider" ] && PROVIDER="$cfg_provider"
    [ -n "$CLI_PROVIDER" ] && PROVIDER="$CLI_PROVIDER"
    case " $KNOWN_PROVIDERS " in *" $PROVIDER "*) ;; *) PROVIDER=deepseek ;; esac
    activate_provider "$PROVIDER"
    if   [ -n "$CLI_MODEL" ];    then MODEL="$CLI_MODEL"
    elif [ -n "${AI_MODEL:-}" ]; then MODEL="$AI_MODEL"
    elif [ -n "$cfg_model" ] && [ "$PROVIDER" = "$cfg_provider" ]; then MODEL="$cfg_model"
    fi
    [ "$PROVIDER" = deepseek ] && [ -n "$cfg_url" ] && API_URL="$cfg_url"
    case "$MAX_TOKENS" in ''|*[!0-9]*) MAX_TOKENS=8000 ;; esac
}

save_config() {   # same file format as the bubble, so both stay in sync
    local k kv m
    MODELS[$PROVIDER]="$MODEL"
    KEYS[$(provider_keyvar "$PROVIDER")]="$API_KEY"
    mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR" 2>/dev/null
    (
        umask 077
        {
            printf 'AI_PROVIDER=%s\n' "$PROVIDER"
            printf 'AI_BASE_URL=%s\n' "$CUSTOM_URL"
            printf 'DEEPSEEK_MAX_TOKENS=%s\nDEEPSEEK_THINKING=%s\nBASH_CONFIRM=%s\n' \
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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/deepseek-chat.XXXXXX")" || exit 1
trap 'rm -rf "$TMP" >/dev/null 2>&1' EXIT
INTERRUPTED=0
trap 'INTERRUPTED=1' INT

ensure_key() {
    [ -n "$API_KEY" ] && return 0
    if [ ! -t 0 ]; then
        echo "No API key for $(provider_label "$PROVIDER"). Set $(provider_keyvar "$PROVIDER") or run interactively once." >&2
        return 1
    fi
    local k
    read -r -s -p "$(provider_label "$PROVIDER") API key (hidden): " k; echo
    k="${k//[$'\n\r\t ']/}"
    [ -z "$k" ] && return 1
    API_KEY="$k"; save_config
    echo "Saved to $CONFIG_FILE"
}

# ── History ──────────────────────────────────────────────────────────────────
HISTORY='[]'; PERSIST=1
hist_save() { [ "$PERSIST" = 1 ] && [ "$HISTORY" != '[]' ] && { mkdir -p "$CONFIG_DIR"; ( umask 077; printf '%s' "$HISTORY" >"$HIST_FILE" ); }; return 0; }
hist_clear() { HISTORY='[]'; rm -f "$HIST_FILE" 2>/dev/null; }
hist_load() {
    [ -s "$HIST_FILE" ] || return 0
    local h; h="$(cat "$HIST_FILE" 2>/dev/null)"
    jq -e 'type == "array" and length > 1' >/dev/null 2>&1 <<<"$h" || return 0
    HISTORY="$h"
}
trim_history() {
    local limit="$1"
    while [ ${#HISTORY} -gt "$limit" ] && [ "$(jq 'length' <<<"$HISTORY")" -gt 2 ]; do
        HISTORY="$(jq -c 'del(.[1])' <<<"$HISTORY")"
        while [ "$(jq -r 'if length > 1 then .[1].role else "" end' <<<"$HISTORY")" = "tool" ]; do
            HISTORY="$(jq -c 'del(.[1])' <<<"$HISTORY")"
        done
    done
}
hist_add() { HISTORY="$(jq -c --argjson m "$1" '. + [$m]' <<<"$HISTORY")"; }

# ── API (streaming) ──────────────────────────────────────────────────────────
json_body() {   # messages array on stdin
    jq -c --arg m "$MODEL" --argjson mt "$MAX_TOKENS" --arg th "$THINKING" \
          --argjson tools "$TOOLS" --arg tf "$TOKEN_FIELD" --arg prov "$PROVIDER" '
        {model:$m, messages:., stream:true} + {($tf):$mt}
        + (if $prov != "deepseek" then {}
           elif $th == "off" then {thinking:{type:"disabled"}}
           elif $th == "on" then {thinking:{type:"enabled"}}
           else {} end)
        + {tools:$tools, tool_choice:"auto"}'
}

ERRMSG=""; MSG=""
api_call() {   # $1 = body -> MSG (assistant message). 0 ok, 1 error, 2 interrupted
    local bodyf="$TMP/body.json" raw="$TMP/raw" sse="$TMP/sse" hdr="$TMP/hdr" cerr="$TMP/cerr" ec code attempt=0
    ERRMSG=""; MSG=""
    printf '%s' "$1" >"$bodyf"
    while :; do
        : >"$raw"; : >"$sse"; : >"$hdr"
        curl -sS -N --max-time 240 -D "$hdr" "$API_URL" \
            -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
            --data-binary @"$bodyf" 2>"$cerr" \
          | tee "$raw" \
          | sed -u -n 's/^data: *//p' \
          | grep --line-buffered -v '^\[DONE\]' \
          | tee "$sse" \
          | jq --unbuffered -j '(.choices[0].delta.content // empty)' 2>/dev/null
        ec=${PIPESTATUS[0]}
        [ "$INTERRUPTED" = 1 ] && return 2
        code="$(grep -i '^HTTP/' "$hdr" | tail -n1 | awk '{print $2}')"
        case "$code" in
            429|500|502|503|504)
                if [ "$attempt" -lt "$HTTP_RETRIES" ]; then
                    attempt=$((attempt+1))
                    printf '%s(retry %s, HTTP %s)%s\n' "$C_DIM" "$attempt" "$code" "$C_RST" >&2
                    sleep "$attempt"; continue
                fi ;;
        esac
        break
    done
    if [ "$ec" -ne 0 ]; then
        ERRMSG="$(head -c 200 "$cerr" | tr -d '\n')"; [ -z "$ERRMSG" ] && ERRMSG="curl exit $ec"
        return 1
    fi
    if [ -n "$code" ] && [ "$code" -ge 400 ] 2>/dev/null; then
        ERRMSG="HTTP $code: $(jq -r '.error.message // empty' "$raw" 2>/dev/null)"
        [ "$ERRMSG" = "HTTP $code: " ] && ERRMSG="HTTP $code: $(head -c 200 "$raw" | tr -d '\n')"
        return 1
    fi
    if [ -s "$sse" ]; then
        MSG="$(jq -sc '
          reduce (.[] | (.choices[0].delta // empty)) as $d ({content:"",tools:{}};
              .content += ($d.content // "")
              | reduce (($d.tool_calls // [])[]) as $tc (.;
                  (($tc.index // 0) | tostring) as $i
                  | .tools[$i] = ((.tools[$i] // {id:null,name:null,arguments:""})
                      | (if ($tc.id // null) != null then .id = $tc.id else . end)
                      | (if ($tc.function.name // null) != null then .name = $tc.function.name else . end)
                      | .arguments += ($tc.function.arguments // ""))))
          | {role:"assistant"}
            + (if (.content | length) > 0 then {content:.content} else {} end)
            + (if (.tools | length) > 0 then
                 {tool_calls: [.tools | to_entries | sort_by(.key | tonumber)[] | .value
                    | {id:(.id // ""), type:"function",
                       function:{name:(.name // ""), arguments:(.arguments // "")}}]}
               else {} end)' "$sse" 2>/dev/null)"
    else
        # endpoint ignored stream:true and sent one JSON object
        if jq -e '.choices[0].message' "$raw" >/dev/null 2>&1; then
            MSG="$(jq -c '.choices[0].message
                  | {role:"assistant", content:(.content // null), tool_calls:(.tool_calls // null)}
                  | with_entries(select(.value != null))' "$raw")"
            jq -r '.choices[0].message.content // empty' "$raw"
        else
            ERRMSG="$(jq -r '.error.message // empty' "$raw" 2>/dev/null)"
            [ -z "$ERRMSG" ] && ERRMSG="unexpected response: $(head -c 120 "$raw" | tr -d '\n')"
            return 1
        fi
    fi
    if [ -z "$MSG" ]; then ERRMSG="could not parse the reply"; return 1; fi
    # never store a message with neither content nor tool_calls (the API rejects it)
    MSG="$(jq -c 'if (has("content") or has("tool_calls")) then . else . + {content:""} end' <<<"$MSG")"
    return 0
}

# ── Tool: run_bash ───────────────────────────────────────────────────────────
TOOL_OUT=""
run_bash_tool() {   # $1 = command -> TOOL_OUT
    local cmd="$1" of="$TMP/tool.out" ec out ans
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    printf '%s\t%s\n' "$(date '+%F %T')" "$cmd" >>"$CMD_LOG" 2>/dev/null
    if [ "$CONFIRM_DANGEROUS" = 1 ] && printf '%s' "$cmd" | grep -Eq "$RISKY_PATTERN"; then
        read -r -p "${C_ERR}⚠ risky command — run it? [y/N] ${C_RST}" ans </dev/tty
        case "$ans" in y|Y|yes) ;; *) TOOL_OUT="exit=126"$'\n'"(the user declined this command)"; return ;; esac
    fi
    ( cd "$HOME" && exec timeout --foreground -k 5 "$CMD_TIMEOUT" bash -c "$cmd" ) </dev/null >"$of" 2>&1
    ec=$?
    if [ "$INTERRUPTED" = 1 ]; then TOOL_OUT="exit=130"$'\n'"(stopped by user)"; return; fi
    out="exit=$ec"$'\n'"$(cat "$of" 2>/dev/null)"
    [ ${#out} -gt "$OUT_LIMIT" ] && out="${out:0:$OUT_LIMIT}"$'\n...[truncated]'
    TOOL_OUT="$out"
}

# ── Agent loop ───────────────────────────────────────────────────────────────
agent() {   # $1 = user text
    local user="$1" i n j callid cargs cmd out toolmsg rc body run_start=$SECONDS
    if [ "$HISTORY" = '[]' ]; then
        HISTORY="$(jq -nc --arg s "$SYSTEM_PROMPT" '[{role:"system",content:$s}]')"
    fi
    trim_history "$HIST_LIMIT"
    HISTORY="$(jq -c --arg c "$user" '. + [{role:"user",content:$c}]' <<<"$HISTORY")"
    INTERRUPTED=0
    for ((i=0; i<MAX_ITERS; i++)); do
        if [ $((SECONDS - run_start)) -gt 300 ]; then echo "${C_ERR}(stopped: 300s run budget used up)${C_RST}"; break; fi
        trim_history "$HIST_HARD_LIMIT"
        body="$(json_body <<<"$HISTORY")"
        printf '%s🤖 %s' "$C_ACC" "$C_RST"
        api_call "$body"; rc=$?
        if [ "$rc" = 2 ]; then INTERRUPTED=0; echo; echo "${C_DIM}(stopped)${C_RST}"; break; fi
        if [ "$rc" != 0 ]; then echo; echo "${C_ERR}Error: ${ERRMSG}${C_RST}" >&2; break; fi
        echo
        hist_add "$MSG"
        if jq -e '(.tool_calls // []) | length > 0' >/dev/null 2>&1 <<<"$MSG"; then
            n="$(jq '.tool_calls | length' <<<"$MSG")"
            for ((j=0; j<n; j++)); do
                callid="$(jq -r ".tool_calls[$j].id" <<<"$MSG")"
                cargs="$(jq -r ".tool_calls[$j].function.arguments" <<<"$MSG")"
                cmd="$(jq -r '.command // empty' <<<"$cargs" 2>/dev/null)"
                if [ -z "$cmd" ]; then
                    out="ERROR: tool call arguments were not valid JSON — the reply was probably cut off by max_tokens. Use shorter commands."
                elif [ "$INTERRUPTED" = 1 ]; then
                    out="(stopped by user)"
                else
                    printf '%s$ %s%s\n' "$C_DIM" "$cmd" "$C_RST"
                    run_bash_tool "$cmd"; out="$TOOL_OUT"
                    printf '%s%s%s\n' "$C_DIM" "$out" "$C_RST"
                fi
                toolmsg="$(jq -nc --arg id "$callid" --arg c "$out" '{role:"tool", tool_call_id:$id, content:$c}')"
                hist_add "$toolmsg"
            done
            if [ "$INTERRUPTED" = 1 ]; then INTERRUPTED=0; echo "${C_DIM}(stopped)${C_RST}"; break; fi
            continue
        fi
        break
    done
    [ "$i" -ge "$MAX_ITERS" ] && echo "${C_DIM}(stopped after $MAX_ITERS tool iterations)${C_RST}"
    hist_save
}

# ── One-shot mode: text arguments and/or piped stdin ─────────────────────────
HAS_STDIN=0; { [ -p /dev/stdin ] || [ -f /dev/stdin ]; } && HAS_STDIN=1
if [ ${#ARGS[@]} -gt 0 ] || [ "$HAS_STDIN" = 1 ]; then
    q="${ARGS[*]:-}"
    if [ "$HAS_STDIN" = 1 ]; then
        piped="$(cat)"
        q="${q:+$q$'\n\n'}$piped"
    fi
    [ -z "${q//[[:space:]]/}" ] && { echo "Nothing to send." >&2; exit 1; }
    ensure_key || exit 1
    PERSIST=0
    agent "$q"
    exit 0
fi

# ── Interactive chat ─────────────────────────────────────────────────────────
ensure_key || exit 1
[ "$NEW" = 1 ] && hist_clear || hist_load
restored=0; [ "$HISTORY" != '[]' ] && restored=$(( $(jq 'length' <<<"$HISTORY") - 1 ))

echo "${C_ACC}⚡ $(provider_label "$PROVIDER")${C_RST} · $MODEL   ${C_DIM}(/help for commands, Ctrl-D to quit)${C_RST}"
[ "$restored" -gt 0 ] && echo "${C_DIM}Restored $restored messages from the last session (/reset to clear).${C_RST}"

while :; do
    INTERRUPTED=0
    read -e -r -p "you› " line; rc=$?
    if [ "$rc" -gt 128 ]; then echo; continue; fi        # Ctrl-C at the prompt
    [ "$rc" -ne 0 ] && { echo; break; }                  # Ctrl-D
    [ -z "${line//[[:space:]]/}" ] && continue
    history -s "$line"
    case "$line" in
        /exit|/quit|/q) break ;;
        /help)
            echo "  /reset            clear the conversation"
            echo "  /model [id]       show or change the model"
            echo "  /provider [name]  show or change provider ($KNOWN_PROVIDERS)"
            echo "  /confirm on|off   ask before risky shell commands (now: $([ "$CONFIRM_DANGEROUS" = 1 ] && echo on || echo off))"
            echo "  /exit             quit   (Ctrl-C stops a running answer)"
            continue ;;
        /reset) hist_clear; echo "Conversation reset."; continue ;;
        /model)   echo "$PROVIDER · $MODEL"; continue ;;
        "/model "*)
            MODEL="${line#/model }"; MODEL="${MODEL//[$'\n\r\t ']/}"
            save_config; echo "Model → $MODEL"; continue ;;
        /provider) echo "$PROVIDER   (available: $KNOWN_PROVIDERS)"; continue ;;
        "/provider "*)
            p="${line#/provider }"; p="${p//[$'\n\r\t ']/}"
            case " $KNOWN_PROVIDERS " in
                *" $p "*)
                    activate_provider "$p"
                    ensure_key || { echo "No key — staying without one."; continue; }
                    save_config; echo "${C_ACC}⚡ $(provider_label "$PROVIDER")${C_RST} · $MODEL" ;;
                *) echo "Unknown provider: $p" ;;
            esac
            continue ;;
        "/confirm "*)
            case "${line#/confirm }" in
                on)  CONFIRM_DANGEROUS=1; save_config; echo "Risky commands will ask first." ;;
                off) CONFIRM_DANGEROUS=0; save_config; echo "Commands run without asking." ;;
                *)   echo "Use: /confirm on|off" ;;
            esac
            continue ;;
        /*) echo "Unknown command (try /help)"; continue ;;
    esac
    agent "$line"
    echo
done
exit 0
