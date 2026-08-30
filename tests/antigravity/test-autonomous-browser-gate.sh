#!/usr/bin/env bash
# Test: Autonomous Frontend Browser Gate (Antigravity 2.0)
# Heavy integration test: provisions Playwright Chromium, runs one approved frontend
# mission, then independently proves the final UI in a real browser.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

for cmd in agy node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[SKIP] '$cmd' not found; browser integration test requires agy + Node.js/npm."
        exit 0
    fi
done

TEST_PROJECT=$(create_test_project)
SERVER_PID=""
cleanup() {
    if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null || true; fi
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
  "scripts": {
    "start": "node src/server.js",
    "test": "node --test"
  },
  "devDependencies": {
    "playwright": "^1.55.0"
  }
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

export const server = http.createServer(async (req, res) => {
  try {
    const pathname = req.url === '/' ? '/index.html' : req.url;
    const file = await readFile(path.join(root, pathname));
    res.writeHead(200, { 'content-type': pathname.endsWith('.html') ? 'text/html; charset=utf-8' : 'text/plain; charset=utf-8' });
    res.end(file);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
});

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  server.listen(port, '127.0.0.1', () => console.log(`ready:${port}`));
}
EOF

cat > public/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Greeting</title></head>
<body>
  <main>
    <h1>Greeting</h1>
    <p>The interactive greeting feature has not been implemented yet.</p>
  </main>
</body>
</html>
EOF

cat > test/baseline.test.js <<'EOF'
import test from 'node:test';
import assert from 'node:assert/strict';

test('baseline is healthy', () => assert.equal(2 * 3, 6));
EOF

# Install the test fixture's browser harness before the mission so browser-verifier
# can use an existing project dependency rather than mutating product dependencies.
if ! npm install --no-audit --no-fund >/dev/null 2>&1; then
    echo "[SKIP] npm install for Playwright fixture failed (network/environment)."
    exit 0
fi
if ! npx playwright install chromium >/dev/null 2>&1; then
    echo "[SKIP] Playwright Chromium installation failed in this environment."
    exit 0
fi

git add .
git commit -m "frontend fixture baseline" --quiet
BASE_SHA=$(git rev-parse HEAD)

read -r -d '' PROMPT <<'EOF' || true
Use the autonomous development path. The Mission Brief below is already approved. Do not ask for another approval and do not ask whether to continue.

# Mission: Interactive Greeting UI

## Goal
Turn the existing placeholder page into a working greeting interaction that is proven in a real browser.

## Constraints
- Keep the existing Node built-in HTTP server and port 4173.
- No application runtime dependencies.
- Plain HTML/CSS/JavaScript is sufficient; do not introduce a framework.
- Existing tests must keep passing.

## Broad Workstreams
1. Implement the greeting interaction in the existing page.
   - Done when the page has a text input, an action button, and a visible result; entering `Alice` then activating the button shows exactly `Hello, Alice!`; an empty input shows exactly `Hello, World!`.
2. Integrate and harden the user flow.
   - Done when both interactions work after loading the page from the real local server, with no relevant browser console/page errors.

## Final Acceptance
- `npm test` passes.
- The local application is started and the complete greeting flow is exercised in a real browser.
- Browser evidence proves both named and empty-name cases on the final HEAD.
- Independent static mission review and every required execution gate pass.

## Verification Surfaces
- Node test suite.
- Real local HTTP server.
- Real browser interaction, console/page errors, and screenshot evidence.

Execute autonomously now. If any reviewer or verifier finds a problem, repair it and repeat the affected gates. Only stop for a genuine autonomous-development blocker.
EOF

OUTPUT_FILE="$TEST_PROJECT/agy-output.txt"
TRANSCRIPT_FILE="$TEST_PROJECT/agy-transcript.jsonl"

if OUTPUT=$(run_antigravity "$PROMPT" 3600); then
    printf '%s\n' "$OUTPUT" > "$OUTPUT_FILE"
else
    status=$?
    printf '%s\n' "${OUTPUT:-}" > "$OUTPUT_FILE"
    echo "[FAIL] autonomous frontend mission failed with exit code $status"
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

if npm test > "$TEST_PROJECT/final-test-output.txt" 2>&1; then
    pass "final npm test passes"
else
    fail "final npm test failed"
fi

if contains_anywhere "browser-verifier"; then
    pass "browser-verifier appears in mission execution evidence"
else
    fail "browser-verifier was not dispatched/evidenced"
fi

if contains_anywhere "workstream-reviewer" && contains_anywhere "mission-reviewer"; then
    pass "static workstream and mission review gates appear"
else
    fail "expected static review gates not visible"
fi

if git diff --quiet "$BASE_SHA"..HEAD --; then
    fail "frontend mission made no committed changes"
else
    pass "frontend mission produced committed changes"
fi

# Independently verify the finished product. This is outside the agent's own evidence,
# so a false browser-verifier PASS cannot make the harness green.
mkdir -p .browser-test
npm start > .browser-test/server.log 2>&1 &
SERVER_PID=$!

cat > .browser-test/verify.mjs <<'EOF'
import { chromium } from 'playwright';
import { writeFile } from 'node:fs/promises';

const base = 'http://127.0.0.1:4173/';
let ready = false;
for (let i = 0; i < 80; i++) {
  try {
    const r = await fetch(base);
    if (r.ok) { ready = true; break; }
  } catch {}
  await new Promise(r => setTimeout(r, 250));
}
if (!ready) throw new Error('server never became ready');

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', e => errors.push(`pageerror:${e.message}`));
page.on('console', m => { if (m.type() === 'error') errors.push(`console:${m.text()}`); });

await page.goto(base, { waitUntil: 'networkidle' });
const input = page.locator('input').first();
const button = page.locator('button').first();
if (await input.count() !== 1 || await button.count() !== 1) {
  throw new Error('expected greeting input and button were not found');
}

await input.fill('Alice');
await button.click();
if (await page.getByText('Hello, Alice!', { exact: true }).count() !== 1) {
  throw new Error('named greeting not visible');
}

await input.fill('');
await button.click();
if (await page.getByText('Hello, World!', { exact: true }).count() !== 1) {
  throw new Error('default greeting not visible');
}

await page.screenshot({ path: '.browser-test/final.png', fullPage: true });
await writeFile('.browser-test/errors.json', JSON.stringify(errors, null, 2));
await browser.close();

if (errors.length) throw new Error(`browser errors: ${errors.join(' | ')}`);
EOF

if node .browser-test/verify.mjs > .browser-test/verify.log 2>&1; then
    pass "independent real-browser acceptance passes"
else
    fail "independent real-browser acceptance failed"
    sed 's/^/    /' .browser-test/verify.log || true
fi

if grep -Eqi 'should I continue|shall I continue|would you like me to continue|approve this (plan|mission)|waiting for (your )?approval' "$OUTPUT_FILE"; then
    fail "routine human approval/continue gate appeared"
else
    pass "no routine human approval/continue gate"
fi

echo ""
echo "========================================"
echo " Browser Gate Test Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Text log:       $OUTPUT_FILE"
echo "Transcript log: $TRANSCRIPT_FILE"

if [ "$FAILED" -gt 0 ]; then exit 1; fi
echo "[PASS] autonomous frontend browser gate harness passed"
