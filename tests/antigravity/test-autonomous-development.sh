#!/usr/bin/env bash
# Test: Autonomous Development Mission (Antigravity 2.0)
# Exercises the autonomous path from an already-approved broad Mission Brief.
# This is intentionally outcome-oriented: it does not prescribe internal microtasks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

if ! command -v agy &>/dev/null; then
    echo "[SKIP] 'agy' command not found. Install Antigravity CLI to run this test."
    exit 0
fi

TEST_PROJECT=$(create_test_project)
trap "cleanup_test_project '$TEST_PROJECT'" EXIT
cd "$TEST_PROJECT"

git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"

cat > package.json <<'EOF'
{
  "name": "autonomous-mission-test",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

mkdir -p test
cat > test/baseline.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';

test('baseline is healthy', () => {
  assert.equal(1 + 1, 2);
});
EOF

git add .
git commit -m "test fixture baseline" --quiet
BASE_SHA=$(git rev-parse HEAD)

read -r -d '' PROMPT <<'EOF' || true
Use the autonomous development path. This Mission Brief is already approved; do not ask me to approve it again and do not ask whether to continue between workstreams.

# Mission: Greeting CLI

## Goal
Add a small greeting CLI that is complete, tested, and usable from the command line.

## Constraints
- JavaScript ESM only.
- Use only Node.js built-ins; add no runtime dependencies.
- Keep existing baseline behavior passing.

## Broad Workstreams
1. Implement the reusable greeting behavior.
   - Done when the project exposes a tested greeting function that returns `Hello, <name>!` and defaults an omitted/empty name to `World`.
2. Integrate that behavior into a CLI entry point.
   - Done when `node src/cli.js Alice` prints exactly `Hello, Alice!` and `node src/cli.js` prints exactly `Hello, World!`.

## Final Acceptance
- `npm test` passes.
- Both CLI commands above produce the required output.
- The whole mission has passed independent implementation review and runtime verification.

## Verification Surfaces
- Node test suite.
- Real CLI invocation.

Execute this mission autonomously now. Make reasonable reversible engineering decisions yourself. If a reviewer or runtime check finds a defect, repair it and re-run the affected gates. Stop only for a genuine autonomous-development blocker.
EOF

echo "========================================"
echo " Test: Autonomous Development Mission"
echo "========================================"
echo "Project: $TEST_PROJECT"
echo "Base:    $BASE_SHA"
echo ""

OUTPUT_FILE="$TEST_PROJECT/agy-output.txt"
TRANSCRIPT_FILE="$TEST_PROJECT/agy-transcript.jsonl"

# Execute the mission exactly once. The user-visible text capture is retained for
# diagnostics; the authoritative tool/subagent evidence is copied from the same
# conversation's transcript after that run.
if OUTPUT=$(run_antigravity "$PROMPT" 3600); then
    printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"
else
    status=$?
    printf '%s\n' "${OUTPUT:-}" > "$OUTPUT_FILE"
    echo "[FAIL] autonomous mission agy run failed with exit code $status"
    exit "$status"
fi

TRANSCRIPT=$(find_transcript 90 "$TEST_PROJECT" 2>/dev/null || true)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    cp "$TRANSCRIPT" "$TRANSCRIPT_FILE"
else
    : > "$TRANSCRIPT_FILE"
fi

FAILED=0
PASSED=0

pass() { echo "  [PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  [FAIL] $1"; FAILED=$((FAILED + 1)); }

contains_anywhere() {
    local needle="$1"
    grep -Fqi -- "$needle" "$OUTPUT_FILE" "$TRANSCRIPT_FILE" 2>/dev/null
}

echo ""
echo "=== Outcome checks ==="

if [ -f src/cli.js ]; then pass "src/cli.js exists"; else fail "src/cli.js missing"; fi

if npm test > "$TEST_PROJECT/final-test-output.txt" 2>&1; then
    pass "final npm test passes"
else
    fail "final npm test failed"
    sed 's/^/    /' "$TEST_PROJECT/final-test-output.txt" || true
fi

CLI_ALICE=$(node src/cli.js Alice 2>&1 || true)
if [ "$CLI_ALICE" = "Hello, Alice!" ]; then
    pass "real CLI invocation with name"
else
    fail "CLI with name: expected 'Hello, Alice!', got '$CLI_ALICE'"
fi

CLI_DEFAULT=$(node src/cli.js 2>&1 || true)
if [ "$CLI_DEFAULT" = "Hello, World!" ]; then
    pass "real CLI invocation default"
else
    fail "CLI default: expected 'Hello, World!', got '$CLI_DEFAULT'"
fi

if git diff --quiet "$BASE_SHA"..HEAD --; then
    fail "mission made no committed changes"
else
    pass "mission produced committed changes"
fi

if [ -f .superpowers/.gitignore ] && [ -d .superpowers/missions ]; then
    pass "durable mission workspace/ledger root exists"
else
    fail "mission workspace/ledger root missing"
fi

echo ""
echo "=== Orchestration checks ==="

# failure-investigator is intentionally absent: a healthy fixture should converge
# without entering the repeated-failure recovery ladder.
for agent in workstream-planner mission-implementer spec-reviewer code-reviewer workstream-reviewer runtime-verifier mission-reviewer; do
    if contains_anywhere "$agent"; then
        pass "dispatch/evidence mentions $agent"
    else
        fail "no dispatch/evidence found for $agent"
    fi
done

# The prompt explicitly pre-approved the Mission Brief. A routine approval/continue
# question is therefore a regression in the autonomous path. Avoid broad words such
# as "approval" because the agent may accurately state that approval was pre-granted.
if grep -Eqi 'should I continue|shall I continue|would you like me to continue|ready to execute\?|approve this (plan|mission)|waiting for (your )?approval' "$OUTPUT_FILE"; then
    fail "routine human approval/continue gate appeared"
else
    pass "no routine human approval/continue gate"
fi

if contains_anywhere "autonomous-development"; then
    pass "autonomous-development path visible in execution evidence"
else
    fail "autonomous-development path not visible in execution evidence"
fi

echo ""
echo "========================================"
echo " Test Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Text log:       $OUTPUT_FILE"
echo "Transcript log: $TRANSCRIPT_FILE"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "[PASS] autonomous mission end-to-end harness passed"
