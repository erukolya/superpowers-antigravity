#!/usr/bin/env node

import fs from "node:fs";
import { spawnSync } from "node:child_process";

const FAIL_OPEN = process.env.SUPERPOWERS_COMPLETION_GATE_FAIL_OPEN === "1";
const REVIEW_ACTIVE = process.env.SUPERPOWERS_COMPLETION_REVIEW_ACTIVE === "1";
const AGY_BIN = process.env.SUPERPOWERS_AGY_BIN || "agy";
const REVIEW_MODEL = process.env.SUPERPOWERS_COMPLETION_REVIEW_MODEL || "";
const REVIEW_EFFORT = process.env.SUPERPOWERS_COMPLETION_REVIEW_EFFORT || "high";
const REVIEW_TIMEOUT = process.env.SUPERPOWERS_COMPLETION_REVIEW_TIMEOUT || "15m";
const PROCESS_TIMEOUT_MS = Number(process.env.SUPERPOWERS_COMPLETION_REVIEW_PROCESS_TIMEOUT_MS || 960000);

const MUTATION_TYPES = new Set([
  "CODE_ACTION",
  "WRITE_TO_FILE",
  "REPLACE_FILE_CONTENT",
  "MULTI_REPLACE_FILE_CONTENT"
]);

const MUTATION_TOOLS = new Set([
  "write_to_file",
  "replace_file_content",
  "multi_replace_file_content",
  "invoke_subagent"
]);

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function stop(reason) {
  emit(reason ? { decision: "stop", reason } : { decision: "stop" });
}

function continueExecution(reason) {
  emit({ decision: "continue", reason });
}

function failGate(message) {
  if (FAIL_OPEN) {
    console.error(`[completion-gate] ${message}`);
    stop(`Independent completion review failed open: ${message}`);
    return;
  }

  continueExecution(
    `Independent completion review could not complete, so completion is blocked. ${message}\n` +
    `Resolve the review failure before claiming the task is complete.`
  );
}

function stripUserEnvelope(content) {
  if (typeof content !== "string") return "";
  const match = content.match(/<USER_REQUEST>\s*([\s\S]*?)\s*<\/USER_REQUEST>/i);
  return (match ? match[1] : content).trim();
}

function inspectRecord(value, state) {
  if (!value || typeof value !== "object") return;

  if (Array.isArray(value)) {
    for (const item of value) inspectRecord(item, state);
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    if (/^targetfile$/i.test(key) && typeof child === "string" && child.trim()) {
      state.touchedFiles.add(child.trim());
      state.hasMutation = true;
    }

    if (/^(name|tool_name|toolName)$/i.test(key) && typeof child === "string" && MUTATION_TOOLS.has(child)) {
      state.hasMutation = true;
    }

    inspectRecord(child, state);
  }
}

function readTranscript(transcriptPath) {
  const state = {
    userRequests: [],
    touchedFiles: new Set(),
    hasMutation: false
  };

  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    return { userRequests: [], touchedFiles: [], hasMutation: false };
  }

  const text = fs.readFileSync(transcriptPath, "utf8");
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue;

    let record;
    try {
      record = JSON.parse(line);
    } catch {
      continue;
    }

    if (record?.source === "USER_EXPLICIT" && record?.type === "USER_INPUT") {
      const request = stripUserEnvelope(record.content);
      if (request) state.userRequests.push(request);
    }

    if (MUTATION_TYPES.has(record?.type)) {
      state.hasMutation = true;
    }

    inspectRecord(record, state);
  }

  return {
    userRequests: state.userRequests,
    touchedFiles: [...state.touchedFiles],
    hasMutation: state.hasMutation
  };
}

function buildPrompt(input, transcript) {
  const requests = transcript.userRequests.length
    ? transcript.userRequests.map((x, i) => `--- User request ${i + 1} ---\n${x}`).join("\n\n")
    : "No USER_EXPLICIT/USER_INPUT records could be extracted. Recover requirements from repository task/spec/plan artifacts and do not infer completion from the worker's claims.";

  const touched = transcript.touchedFiles.length
    ? transcript.touchedFiles.map(x => `- ${x}`).join("\n")
    : "- No modified-file paths were recoverable from the transcript. Inspect git status/history and task artifacts yourself.";

  const workspaces = Array.isArray(input.workspacePaths) ? input.workspacePaths.join("\n- ") : "";

  return `You are an INDEPENDENT FINAL COMPLETION REVIEWER in a fresh session.

Your only job is to decide whether the actual repository state fully satisfies the user's requested work and all applicable project/plugin rules.

CRITICAL INDEPENDENCE RULES:
- Do NOT trust the previous worker's statements, summaries, confidence, or claims of success.
- Do NOT reuse the previous worker's reasoning.
- Verify the repository state yourself.
- Treat tests/build claims as untrusted unless you can find concrete fresh evidence or independently verify them.
- Do not edit files. This is a read-only review.
- Do not lower the bar because the implementation is close.

WHAT TO VERIFY:
1. Reconstruct the requested outcome from the explicit user requests below plus repository plan/spec/task artifacts.
2. Inspect the actual implementation, including git status, relevant git diff/history, touched files, and surrounding code.
3. Check every material requirement, edge case, and integration point that the task implies.
4. Check all applicable repository instructions/rules (for example AGENTS.md, GEMINI.md, .agents/rules/**, task.md, design/plan/spec artifacts, and relevant Superpowers workflow requirements).
5. Check for stubs, TODOs, placeholders, disabled code, fake tests, skipped tests, swallowed errors, hard-coded shortcuts, partial implementations, and claims not backed by code.
6. Verify build/tests/browser evidence when relevant. You may run verification commands or tests, but do not modify source files.
7. If anything material is missing, incorrect, unverified, or rule-breaking, verdict MUST be FAIL.
8. PASS only when the task is actually complete enough to hand control back to the user.

WORKSPACES:
- ${workspaces || "(not provided)"}

FILES TO PAY SPECIAL ATTENTION TO (recovered from the worker transcript; not authoritative):
${touched}

EXPLICIT USER REQUESTS (authoritative; worker/model messages intentionally omitted):
${requests}

Return a concise structured verdict. required_actions must contain concrete actions the worker can execute. evidence must cite files/lines, commands, test results, or other directly checked facts.`;
}

function parseResult(stdout) {
  let terminal = null;

  for (const line of String(stdout || "").split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (event?.event === "result") terminal = event.result;
    } catch {
      // Diagnostics belong on stderr, but ignore any accidental non-JSON stdout.
    }
  }

  return terminal;
}

let stdin = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => { stdin += chunk; });
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(stdin || "{}");
  } catch (error) {
    failGate(`Invalid Stop hook input: ${error.message}`);
    return;
  }

  // The reviewer's own fresh agy session loads the same plugin. Never recurse.
  if (REVIEW_ACTIVE) {
    stop();
    return;
  }

  // Do not turn crashes, user cancellations, max-step exits, etc. into fake completion loops.
  if (input.terminationReason && input.terminationReason !== "model_stop") {
    stop();
    return;
  }

  const transcript = readTranscript(input.transcriptPath);

  // Normal questions/planning sessions should finish normally. The gate exists for completed code work.
  if (!transcript.hasMutation) {
    stop();
    return;
  }

  if (input.fullyIdle === false) {
    continueExecution(
      "Completion is blocked because background/asynchronous tasks are still running. Wait for them, inspect their results, then attempt completion again."
    );
    return;
  }

  const workspace = Array.isArray(input.workspacePaths) && input.workspacePaths.length
    ? input.workspacePaths[0]
    : process.cwd();

  const prompt = buildPrompt(input, transcript);

  const schema = JSON.stringify({
    type: "object",
    additionalProperties: false,
    properties: {
      verdict: { type: "string", enum: ["PASS", "FAIL"] },
      summary: { type: "string" },
      required_actions: { type: "array", items: { type: "string" } },
      evidence: { type: "array", items: { type: "string" } }
    },
    required: ["verdict", "summary", "required_actions", "evidence"]
  });

  const args = [
    "--input-format", "stream-json",
    "--output-format", "stream-json",
    "--json-schema", schema,
    "--mode=plan",
    "--effort", REVIEW_EFFORT,
    "--print-timeout", REVIEW_TIMEOUT,
    "--dangerously-skip-permissions",
    "--cwd", workspace
  ];

  if (REVIEW_MODEL) {
    args.push("--model", REVIEW_MODEL);
  }

  const userEvent = JSON.stringify({
    event: "user",
    message: { content: prompt }
  }) + "\n";

  const child = spawnSync(AGY_BIN, args, {
    cwd: workspace,
    env: {
      ...process.env,
      SUPERPOWERS_COMPLETION_REVIEW_ACTIVE: "1"
    },
    input: userEvent,
    encoding: "utf8",
    timeout: PROCESS_TIMEOUT_MS,
    maxBuffer: 64 * 1024 * 1024,
    windowsHide: true
  });

  if (child.stderr) process.stderr.write(child.stderr);

  if (child.error) {
    failGate(`Could not start independent reviewer (${AGY_BIN}): ${child.error.message}`);
    return;
  }

  const result = parseResult(child.stdout);
  if (!result) {
    failGate(`Independent reviewer produced no terminal result (exit ${child.status ?? "unknown"}).`);
    return;
  }

  if (result.status !== "SUCCESS") {
    failGate(`Independent reviewer ended with status ${result.status}: ${result.error || "unknown error"}`);
    return;
  }

  const review = result.structured_output;
  if (!review || !["PASS", "FAIL"].includes(review.verdict)) {
    failGate("Independent reviewer returned an invalid structured verdict.");
    return;
  }

  if (review.verdict === "PASS") {
    console.error(`[completion-gate] PASS: ${review.summary}`);
    stop();
    return;
  }

  const actions = Array.isArray(review.required_actions) && review.required_actions.length
    ? review.required_actions.map((x, i) => `${i + 1}. ${x}`).join("\n")
    : "1. Re-open the task and resolve the deficiencies described by the independent reviewer.";

  const evidence = Array.isArray(review.evidence) && review.evidence.length
    ? `\n\nIndependent evidence:\n${review.evidence.map(x => `- ${x}`).join("\n")}`
    : "";

  continueExecution(
    `Independent completion review: FAIL. Do not hand control back to the user yet.\n\n` +
    `${review.summary}\n\nRequired actions:\n${actions}${evidence}\n\n` +
    `Complete these actions, verify the result, then attempt completion again. A NEW independent review session will be created on the next Stop.`
  );
});
