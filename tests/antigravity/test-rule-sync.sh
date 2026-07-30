#!/usr/bin/env bash
# Test: Rule/Skill Mirror Sync (Static Validation)
# rules/using-superpowers.md carries the using-superpowers bootstrap inline
# instead of an @-reference (the platform docs are self-contradictory about
# relative-path resolution for rule files — see the MIRROR comment in that
# file). This test proves the mirrored body hasn't drifted from
# skills/using-superpowers/SKILL.md, which remains the source of truth.
# This test does NOT require agy — it's purely a static check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/using-superpowers/SKILL.md"
RULE_FILE="${1:-$REPO_ROOT/rules/using-superpowers.md}"

echo "========================================"
echo " Test: Rule/Skill Mirror Sync (Static)"
echo "========================================"
echo ""

[ -f "$SKILL_FILE" ] || { echo "  [FAIL] source file not found: $SKILL_FILE"; exit 1; }
[ -f "$RULE_FILE" ] || { echo "  [FAIL] rule file not found: $RULE_FILE"; exit 1; }

BODY_FILE="$(mktemp)"
cleanup() { rm -f "$BODY_FILE"; }
trap cleanup EXIT

# The mirrored body starts on the line right after the blank line that
# follows the header block's last HTML comment closer ("-->").
MARKER_LINE="$(grep -n -- '-->' "$RULE_FILE" | tail -1 | cut -d: -f1)"

if [ -z "$MARKER_LINE" ]; then
    echo "  [FAIL] no '-->' header terminator found in $RULE_FILE"
    exit 1
fi

BODY_START=$((MARKER_LINE + 2))
tail -n "+$BODY_START" "$RULE_FILE" > "$BODY_FILE"

echo "=== Check: mirrored body (from line $BODY_START of $(basename "$RULE_FILE")) vs SKILL.md ==="
echo ""

if DIFF_OUTPUT="$(diff -u "$SKILL_FILE" "$BODY_FILE")"; then
    echo "  [PASS] mirrored body is byte-identical to SKILL.md"
    echo ""
    echo "========================================"
    echo " Test Summary"
    echo "========================================"
    echo ""
    echo "[PASS] Rule/skill mirror sync test passed"
    exit 0
else
    echo "  [FAIL] mirrored body has drifted from SKILL.md"
    echo ""
    echo "$DIFF_OUTPUT"
    echo ""
    echo "========================================"
    echo " Test Summary"
    echo "========================================"
    echo ""
    echo "[FAIL] Rule/skill mirror sync test failed"
    exit 1
fi
