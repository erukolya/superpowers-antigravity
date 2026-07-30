#!/usr/bin/env bash
# PreToolUse purity gate -- denies write_to_file / replace_file_content /
# multi_replace_file_content calls that would introduce banned vocabulary
# into skills/. This is the SAME law tests/antigravity/test-skill-tool-purity.sh
# enforces in CI (the three pattern groups below are copied verbatim from
# that file's lines 22, 35, 48) -- this hook just catches it before the write
# lands instead of after, at edit time.
#
# --- Contract (fetched 2026-07-30, https://antigravity.google/docs/hooks and
#     https://antigravity.google/docs/ide/hooks; tool-arg names from
#     https://antigravity.google/docs/tools) --------------------------------
#   stdin (PreToolUse):  {"toolCall": {"name": <str>, "args": {...}}, ...}
#   stdout (PreToolUse): {"decision": "allow|deny|ask|force_ask", "reason": <str>}
#   File-tool arg keys: write_to_file -> TargetFile, CodeContent;
#     replace_file_content -> TargetFile, ReplacementContent;
#     multi_replace_file_content -> TargetFile, ReplacementChunks (array;
#     each chunk carries its own ReplacementContent).
#   Exit-code semantics and the hook command's working directory are NOT
#   documented anywhere on either hooks page (confirmed absent on request).
#
# --- Fail-safe policy -------------------------------------------------------
# Antigravity does NOT treat malformed/empty hook stdout as an implicit
# allow: observed real-world behavior (github.com/manaflow-ai/cmux issue
# #5358) is that an unparseable decision -- even a bare "{}" -- gets the
# tool call DENIED with "invalid_args", for every call the matcher covers,
# not just the one under review. So "fail safe" here means "always print a
# well-formed {"decision":"allow"} unless we are POSITIVELY sure this is a
# banned write under skills/" -- never nothing, never a malformed shape. An
# EXIT trap backstops this even against bugs in this script itself.
#
# Deliberately NOT `set -e`: every code path below must still reach the
# trap's fail-open default if something unexpected fails partway through.
set -uo pipefail

DECIDED=0
CONTENTS_FILE=""

# Always emit exactly one decision line, no matter how we got here.
cleanup_and_default() {
    [ -n "$CONTENTS_FILE" ] && [ -f "$CONTENTS_FILE" ] && rm -f "$CONTENTS_FILE"
    if [ "$DECIDED" -eq 0 ]; then
        printf '{"decision":"allow"}\n'
    fi
}
trap cleanup_and_default EXIT

allow() {
    DECIDED=1
    printf '{"decision":"allow"}\n'
    exit 0
}

deny() {
    # $1 = reason text. Callers only ever pass text drawn from the fixed
    # BANNED vocabulary list below (via grep -oE, no wildcards/capture
    # groups) plus a hardcoded suffix, so it can never itself contain a
    # double quote or backslash -- no extra JSON-escaping needed here.
    DECIDED=1
    printf '{"decision":"deny","reason":"%s"}\n' "$1"
    exit 0
}

# Same three pattern groups as tests/antigravity/test-skill-tool-purity.sh:22,35,48.
# Kept as separate variables (not pre-merged) so a future diff against that
# file is a straight line-for-line comparison.
CC_TOOLS='TodoWrite|EnterWorktree|Task tool|Skill tool'
PLATFORMS='Claude Code|Codex CLI|Codex App|Copilot CLI|OpenCode|Factory Droid|Gemini CLI'
MAPPINGS='antigravity-tools|copilot-tools|codex-tools|gemini-tools'
BANNED="${CC_TOOLS}|${PLATFORMS}|${MAPPINGS}"

INPUT="$(cat)"
[ -n "$INPUT" ] || allow   # nothing on stdin -> nothing to check, fail open

CONTENTS_FILE="$(mktemp)" || allow   # can't stage content -> fail open

TARGET_FILE=""
PARSE_OK=0

if command -v jq >/dev/null 2>&1; then
    TARGET_FILE="$(printf '%s' "$INPUT" | jq -r '.toolCall.args.TargetFile? // empty' 2>/dev/null)"
    TF_OK=$?
    printf '%s' "$INPUT" | jq -r '
        [ .toolCall.args.CodeContent?,
          .toolCall.args.ReplacementContent?,
          (.toolCall.args.ReplacementChunks? // [] | .[]? | .ReplacementContent?)
        ] | map(select(type == "string")) | .[]
    ' > "$CONTENTS_FILE" 2>/dev/null
    CONTENT_OK=$?
    if [ "$TF_OK" -eq 0 ] && [ "$CONTENT_OK" -eq 0 ]; then
        PARSE_OK=1
    fi
elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    PY="$(command -v python3 || command -v python)"
    PY_SRC=$(cat <<'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
tc = data.get("toolCall") if isinstance(data, dict) else None
args = tc.get("args") if isinstance(tc, dict) else None
if not isinstance(args, dict):
    args = {}
target = args.get("TargetFile")
if not isinstance(target, str):
    target = ""
blobs = []
for key in ("CodeContent", "ReplacementContent"):
    v = args.get(key)
    if isinstance(v, str):
        blobs.append(v)
chunks = args.get("ReplacementChunks")
if isinstance(chunks, list):
    for chunk in chunks:
        if isinstance(chunk, dict):
            v = chunk.get("ReplacementContent")
            if isinstance(v, str):
                blobs.append(v)
with open(sys.argv[1], "w", encoding="utf-8", newline="") as f:
    for b in blobs:
        f.write(b)
        f.write("\n")
sys.stdout.write(target)
PYEOF
)
    if TARGET_FILE="$(printf '%s' "$INPUT" | "$PY" -c "$PY_SRC" "$CONTENTS_FILE" 2>/dev/null)"; then
        PARSE_OK=1
    fi
else
    allow   # no JSON tool available at all -> can't inspect, fail open
fi

[ "$PARSE_OK" -eq 1 ] || allow   # malformed/unparseable stdin -> fail open

# ---- Scope check: only paths under skills/ are in-law (any depth, either
# slash direction so a Windows-style TargetFile still normalizes correctly).
NORM_PATH="$(printf '%s' "$TARGET_FILE" | tr '\\' '/')"
case "$NORM_PATH" in
    skills/*|*/skills/*) : ;;   # in scope, fall through to content check
    *) allow ;;
esac

# ---- Content check: CONTENTS_FILE holds every candidate content blob
# (CodeContent, ReplacementContent, and EVERY ReplacementChunks[].ReplacementContent),
# one per line. grep -E matches per input line regardless of which content
# source contributed that line, so a single pass covers every chunk.
MATCH=""
if [ -s "$CONTENTS_FILE" ]; then
    MATCH="$(grep -oE "$BANNED" "$CONTENTS_FILE" | head -1)" || true
fi

if [ -n "$MATCH" ]; then
    deny "banned vocabulary '${MATCH}' in skills/ write (see tests/antigravity/test-skill-tool-purity.sh)"
else
    allow
fi
