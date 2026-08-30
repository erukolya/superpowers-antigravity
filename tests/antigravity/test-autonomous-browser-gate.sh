#!/usr/bin/env bash
# Heavy integration: approved frontend task.md -> isolated Flash execution -> mandatory browser gate -> supervisor acceptance.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

for cmd in agy node npm; do
    command -v "$cmd" &>/dev/null || { echo "[SKIP] '$cmd' missing"; exit 0; }
done

TEST_PROJECT=$(create_test_project)
VERIFY_DIR=""
SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    if [ -n "$VERIFY_DIR" ] && [ -d "$VERIFY_DIR" ]; then git -C "$TEST_PROJECT" worktree remove --force "$VERIFY_DIR" >/dev/null 2>&1 || true; fi
    cleanup_test_project "$TEST_PROJECT"
}
trap cleanup EXIT
cd "$TEST_PROJECT"

git init --quiet
git config user.email "test@test.com"
git config user.name "Test User"

cat > package.json <<'EOF'
{
  "name": "autonomous-browser-test",
  "version": "1.0.0",
  "type": "module",
  "scripts": { "start": "node src/server.js", "test": "node --test" },
  "devDependencies": { "playwright": "^1.55.0" }
}
EOF
cat > .gitignore <<'EOF'
node_modules/
.browser-test/
EOF
mkdir -p src public test
cat > src/server.js <<'EOF'
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'public');
const port = Number(process.env.PORT || 4173);
export const server = http.createServer(async (req,res) => {
  try {
    const pathname = req.url === '/' ? '/index.html' : req.url;
    const file = await readFile(path.join(root, pathname));
    res.writeHead(200, {'content-type': pathname.endsWith('.html') ? 'text/html; charset=utf-8' : 'text/plain; charset=utf-8'});
    res.end(file);
  } catch { res.writeHead(404); res.end('Not found'); }
});
if (process.argv[1] === fileURLToPath(import.meta.url)) server.listen(port, '127.0.0.1', () => console.log(`ready:${port}`));
EOF
cat > public/index.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>Greeting</title></head><body><main><h1>Greeting</h1><p>Not implemented.</p></main></body></html>
EOF
cat > test/baseline.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';
test('baseline', () => assert.equal(2 * 3, 6));
EOF
cat > task.md <<'EOF'
# Goal
Turn the placeholder page into a working greeting interaction and prove it in a real browser.

# Broad Plan
1. Implement the greeting interaction in the existing page. Done when the page has a text input, action button, and visible result; `Alice` produces exactly `Hello, Alice!`; empty input produces exactly `Hello, World!`.
2. Integrate and harden the flow. Done when both interactions work from the real local server with no relevant browser console/page errors.

# Constraints
- Keep the Node built-in HTTP server and port 4173.
- No application runtime dependencies or framework.
- Existing tests stay green.

# Final Acceptance
- `npm test` passes.
- The complete greeting flow is exercised in a real browser on final HEAD.
- Browser evidence covers named and empty cases and relevant console/page errors.
EOF

if ! npm install --no-audit --no-fund >/dev/null 2>&1; then echo "[SKIP] npm install failed"; exit 0; fi
if ! npx playwright install chromium >/dev/null 2>&1; then echo "[SKIP] Chromium install failed"; exit 0; fi

git add .
git commit -m "frontend fixture with approved task.md" --quiet
BASE_SHA=$(git rev-parse HEAD)

PROMPT="Execute the already-approved task.md autonomously from start to finish. Do not ask for another approval. Use autonomous-development, including the mandatory real-browser gate, Gemini repair loops, workstream supervisor gates, and final supervisor audit."
OUTPUT_FILE="$TEST_PROJECT/agy-output.txt"
TRANSCRIPT_FILE="$TEST_PROJECT/agy-transcript.jsonl"

if OUTPUT=$(run_antigravity "$PROMPT" 3600); then printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"; else status=$?; printf '%s\n' "${OUTPUT:-}" > "$OUTPUT_FILE"; echo "[FAIL] agy run failed: $status"; exit "$status"; fi
TRANSCRIPT=$(find_transcript 90 "$TEST_PROJECT" 2>/dev/null || true)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then cp "$TRANSCRIPT" "$TRANSCRIPT_FILE"; else : > "$TRANSCRIPT_FILE"; fi

FAILED=0; PASSED=0
pass(){ echo "  [PASS] $1"; PASSED=$((PASSED+1)); }
fail(){ echo "  [FAIL] $1"; FAILED=$((FAILED+1)); }
contains(){ grep -Fqi -- "$1" "$OUTPUT_FILE" "$TRANSCRIPT_FILE" 2>/dev/null; }

contains "mission-controller" && pass "mission-controller evidenced" || fail "mission-controller missing"
contains "browser-verifier" && pass "browser-verifier evidenced" || fail "browser-verifier missing"
contains "READY_FOR_SUPERVISOR_REVIEW" && contains "SUPERVISOR_PASS" && pass "stage supervisor handshake" || fail "stage supervisor handshake missing"
contains "READY_FOR_FINAL_SUPERVISOR_REVIEW" && contains "SUPERVISOR_FINAL_PASS" && pass "final supervisor handshake" || fail "final supervisor handshake missing"
if grep -Eqi 'should I continue|shall I continue|approve this (plan|mission)|waiting for (your )?approval' "$OUTPUT_FILE"; then fail "routine approval gate appeared"; else pass "no routine approval gate"; fi

FINAL_HEAD=$(grep -Eo 'Head: [0-9a-f]{40}' "$OUTPUT_FILE" | tail -1 | awk '{print $2}')
if [ -n "$FINAL_HEAD" ] && git cat-file -e "$FINAL_HEAD^{commit}" 2>/dev/null; then pass "final mission HEAD exists"; else fail "valid final Head: line missing"; fi
[ "$(git rev-parse HEAD)" = "$BASE_SHA" ] && pass "parent HEAD untouched" || fail "parent workspace changed"

if [ -n "$FINAL_HEAD" ]; then
    VERIFY_DIR=$(mktemp -d); rm -rf "$VERIFY_DIR"; git worktree add --detach "$VERIFY_DIR" "$FINAL_HEAD" --quiet
    if (cd "$VERIFY_DIR" && npm install --no-audit --no-fund >/dev/null 2>&1 && npm test > final-test-output.txt 2>&1); then pass "final tests pass"; else fail "final tests/install failed"; fi

    mkdir -p "$VERIFY_DIR/.browser-test"
    (cd "$VERIFY_DIR" && npm start > .browser-test/server.log 2>&1) &
    SERVER_PID=$!
    cat > "$VERIFY_DIR/.browser-test/verify.mjs" <<'EOF'
import { chromium } from 'playwright';
const base = 'http://127.0.0.1:4173/';
let ready = false;
for (let i=0;i<80;i++) { try { const r=await fetch(base); if(r.ok){ready=true;break;} } catch{} await new Promise(r=>setTimeout(r,250)); }
if (!ready) throw new Error('server never became ready');
const browser = await chromium.launch({headless:true});
const page = await browser.newPage({viewport:{width:1280,height:720}});
const errors=[];
page.on('pageerror',e=>errors.push(`pageerror:${e.message}`));
page.on('console',m=>{if(m.type()==='error') errors.push(`console:${m.text()}`);});
await page.goto(base,{waitUntil:'networkidle'});
const input=page.locator('input').first(); const button=page.locator('button').first();
if(await input.count()!==1 || await button.count()!==1) throw new Error('input/button missing');
await input.fill('Alice'); await button.click();
if(await page.getByText('Hello, Alice!',{exact:true}).count()!==1) throw new Error('named greeting missing');
await input.fill(''); await button.click();
if(await page.getByText('Hello, World!',{exact:true}).count()!==1) throw new Error('default greeting missing');
await page.screenshot({path:'.browser-test/final.png',fullPage:true});
await browser.close();
if(errors.length) throw new Error(errors.join(' | '));
EOF
    if (cd "$VERIFY_DIR" && node .browser-test/verify.mjs > .browser-test/verify.log 2>&1); then pass "independent real-browser acceptance passes"; else fail "independent real-browser acceptance failed"; sed 's/^/    /' "$VERIFY_DIR/.browser-test/verify.log" || true; fi
fi

echo "Passed: $PASSED  Failed: $FAILED"
[ "$FAILED" -eq 0 ] || exit 1
echo "[PASS] autonomous browser supervisor harness passed"
