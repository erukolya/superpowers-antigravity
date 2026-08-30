#!/usr/bin/env bash
# Integration: approved task.md -> isolated Flash mission-controller -> supervisor gates -> COMPLETE.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

if ! command -v agy &>/dev/null; then
    echo "[SKIP] 'agy' command not found."
    exit 0
fi

TEST_PROJECT=$(create_test_project)
VERIFY_DIR=""
cleanup() {
    if [ -n "$VERIFY_DIR" ] && [ -d "$VERIFY_DIR" ]; then
        git -C "$TEST_PROJECT" worktree remove --force "$VERIFY_DIR" >/dev/null 2>&1 || true
    fi
    cleanup_test_project "$TEST_PROJECT"
}
trap cleanup EXIT
cd "$TEST_PROJECT"

git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"

cat > package.json <<'EOF'
{
  "name": "autonomous-mission-test",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "test": "node --test" }
}
EOF
mkdir -p test
cat > test/baseline.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';
test('baseline', () => assert.equal(1 + 1, 2));
EOF
cat > task.md <<'EOF'
# Goal
Add a complete greeting CLI.

# Broad Plan
1. Implement reusable greeting behavior. Done when an omitted or empty name produces `Hello, World!` and a supplied name produces `Hello, <name>!`.
2. Integrate it into a CLI. Done when `node src/cli.js Alice` prints exactly `Hello, Alice!` and `node src/cli.js` prints exactly `Hello, World!`.

# Constraints
- JavaScript ESM only.
- Node.js built-ins only.
- Existing tests stay green.

# Final Acceptance
- `npm test` passes.
- Both real CLI invocations above produce the exact required output.
EOF

git add .
git commit -m "fixture baseline with approved task.md" --quiet
BASE_SHA=$(git rev-parse HEAD)

PROMPT="Execute the approved plan in task.md autonomously from start to finish. task.md is already approved; do not ask for another approval. Use the autonomous-development workflow and continue through all Gemini repair/review/verification loops and supervisor gates until COMPLETE or a genuine blocker."
OUTPUT_FILE="$TEST_PROJECT/agy-output.txt"
TRANSCRIPT_FILE="$TEST_PROJECT/agy-transcript.jsonl"

if OUTPUT=$(run_antigravity "$PROMPT" 3600); then
    printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"
else
    status=$?
    printf '%s\n' "${OUTPUT:-}" > "$OUTPUT_FILE"
    echo "[FAIL] agy run failed: $status"
    exit "$status"
fi

TRANSCRIPT=$(find_transcript 90 "$TEST_PROJECT" 2>/dev/null || true)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then cp "$TRANSCRIPT" "$TRANSCRIPT_FILE"; else : > "$TRANSCRIPT_FILE"; fi

FAILED=0; PASSED=0
pass(){ echo "  [PASS] $1"; PASSED=$((PASSED+1)); }
fail(){ echo "  [FAIL] $1"; FAILED=$((FAILED+1)); }
contains(){ grep -Fqi -- "$1" "$OUTPUT_FILE" "$TRANSCRIPT_FILE" 2>/dev/null; }

echo "=== Orchestration ==="
for token in autonomous-development mission-controller workstream-planner mission-implementer spec-reviewer code-reviewer workstream-reviewer runtime-verifier mission-reviewer; do
    if contains "$token"; then pass "$token evidenced"; else fail "$token missing"; fi
done
if contains "READY_FOR_SUPERVISOR_REVIEW" && contains "SUPERVISOR_PASS"; then pass "workstream supervisor handshake"; else fail "workstream supervisor handshake missing"; fi
if contains "READY_FOR_FINAL_SUPERVISOR_REVIEW" && contains "SUPERVISOR_FINAL_PASS"; then pass "final supervisor handshake"; else fail "final supervisor handshake missing"; fi
if grep -Eqi 'should I continue|shall I continue|approve this (plan|mission)|waiting for (your )?approval' "$OUTPUT_FILE"; then fail "routine approval gate appeared"; else pass "no routine approval gate"; fi

FINAL_HEAD=$(grep -Eo 'Head: [0-9a-f]{40}' "$OUTPUT_FILE" | tail -1 | awk '{print $2}')
if [ -n "$FINAL_HEAD" ] && git cat-file -e "$FINAL_HEAD^{commit}" 2>/dev/null; then pass "final mission HEAD reported and exists"; else fail "valid final Head: line missing"; fi

if [ "$(git rev-parse HEAD)" = "$BASE_SHA" ]; then pass "parent workspace HEAD untouched"; else fail "parent workspace was modified instead of isolated controller branch"; fi

if [ -n "$FINAL_HEAD" ] && ! git diff --quiet "$BASE_SHA" "$FINAL_HEAD" --; then pass "isolated mission commit differs from baseline"; else fail "no mission changes found"; fi

if [ -n "$FINAL_HEAD" ]; then
    VERIFY_DIR=$(mktemp -d)
    rm -rf "$VERIFY_DIR"
    git worktree add --detach "$VERIFY_DIR" "$FINAL_HEAD" --quiet
    if (cd "$VERIFY_DIR" && npm test > verify-tests.txt 2>&1); then pass "final npm test passes"; else fail "final npm test failed"; fi
    A=$(cd "$VERIFY_DIR" && node src/cli.js Alice 2>&1 || true)
    D=$(cd "$VERIFY_DIR" && node src/cli.js 2>&1 || true)
    [ "$A" = "Hello, Alice!" ] && pass "named CLI acceptance" || fail "named CLI acceptance: '$A'"
    [ "$D" = "Hello, World!" ] && pass "default CLI acceptance" || fail "default CLI acceptance: '$D'"
fi

echo "Passed: $PASSED  Failed: $FAILED"
[ "$FAILED" -eq 0 ] || exit 1
echo "[PASS] autonomous supervisor mission harness passed"
