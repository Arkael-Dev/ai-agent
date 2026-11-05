#!/usr/bin/env bash
# Tests for resuming a cut-off task: history repair, unfinished detection, "lanjut" detection.
# Run: bash tests/test-resume.sh
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DIR/ai-agent-chat.sh"
fail=0
ok()  { echo "ok   - $1"; }
bad() { echo "FAIL - $1"; fail=1; }

# the chat and the bubble must carry identical helpers
FUNCS='/^hist_repair() {/,/^}/p;/^hist_unfinished() {/,/^}/p;/^is_continue_cmd() {/,/^}/p;/^repeat_fail_hint() {/,/^}/p'
[ "$(sed -n "$FUNCS" "$SRC")" = "$(sed -n "$FUNCS" "$DIR/ai-agent-bubble.sh")" ] && ok "chat and bubble helpers match" || bad "chat and bubble helpers match"

declare -A FAIL_COUNT=()
# load only the helper functions from the chat script
eval "$(sed -n "$FUNCS" "$SRC")"

# 1) a dangling tool call gets a reply
H='[{"role":"system","content":"s"},{"role":"user","content":"install x"},{"role":"assistant","tool_calls":[{"id":"a","type":"function","function":{"name":"run_bash","arguments":"{}"}},{"id":"b","type":"function","function":{"name":"run_bash","arguments":"{}"}}]},{"role":"tool","tool_call_id":"a","content":"exit=0"}]'
R="$(hist_repair <<<"$H")"
[ "$(jq 'length' <<<"$R")" = 5 ] && [ "$(jq -r '.[4].tool_call_id' <<<"$R")" = b ] && ok "dangling tool call repaired" || bad "dangling tool call repaired"

# 2) a complete history is left alone
C='[{"role":"system","content":"s"},{"role":"user","content":"hi"},{"role":"assistant","content":"hello"}]'
[ "$(hist_repair <<<"$C")" = "$C" ] && ok "complete history unchanged" || bad "complete history unchanged"

# 3) unfinished detection
HISTORY="$R"; hist_unfinished && ok "tool result at the end = unfinished" || bad "tool result at the end = unfinished"
HISTORY='[{"role":"system","content":"s"},{"role":"user","content":"do it"}]'; hist_unfinished && ok "user request without answer = unfinished" || bad "user request without answer = unfinished"
HISTORY="$C"; hist_unfinished && bad "finished answer = not unfinished" || ok "finished answer = not unfinished"
HISTORY='[{"role":"system","content":"s"}]'; hist_unfinished && bad "system only = not unfinished" || ok "system only = not unfinished"

# 4) continue phrases
for p in "lanjut" "lanjutin" "Lanjutkan tugasnya" "terusin" "continue" "ok, resume" "gas" "keep going"; do
    is_continue_cmd "$p" && ok "continue: $p" || bad "continue: $p"
done
for p in "buatkan script backup" "apa itu bash" "list files in downloads"; do
    is_continue_cmd "$p" && bad "not continue: $p" || ok "not continue: $p"
done

# 5) the same failing command gets a hint on the 2nd failure; success clears it
repeat_fail_hint "touch /x/y" 1 "exit=1"; case "$TOOL_OUT" in *hint*) bad "no hint on 1st failure";; *) ok "no hint on 1st failure";; esac
repeat_fail_hint "touch /x/y" 1 "exit=1"; case "$TOOL_OUT" in *"failed 2 times"*) ok "hint on 2nd failure";; *) bad "hint on 2nd failure";; esac
repeat_fail_hint "touch /x/y" 0 "exit=0"; case "$TOOL_OUT" in *hint*) bad "success clears";; *) ok "success clears";; esac
repeat_fail_hint "touch /x/y" 1 "exit=1"; case "$TOOL_OUT" in *hint*) bad "count reset after success";; *) ok "count reset after success";; esac

exit $fail
