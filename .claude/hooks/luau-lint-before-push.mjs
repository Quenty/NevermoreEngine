#!/usr/bin/env node
// PreToolUse(Bash) hook: run the Luau type check before Claude runs `git push`.
//
// This is the Claude-scoped equivalent of a git pre-push hook. It fires ONLY
// when Claude is about to execute a `git push` via the Bash tool -- never on
// manual pushes from a terminal, and only inside Claude Code. Non-push Bash
// commands pass straight through.
//
// The lint rebuilds the sourcemap and downloads Roblox types (via prelint:luau),
// so it is intentionally gated to push time rather than every edit.
//
// Exit codes:
//   0  -> not a push, or lint passed -> allow the command
//   2  -> lint failed -> block the push and hand the errors back to Claude

import { spawnSync } from "node:child_process";

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.exit(0); // no/garbled payload -> don't block the command
  }

  const command = payload?.tool_input?.command ?? "";
  // Match `git push` only in command position -- at the start of the line or
  // right after a shell separator (; && || | ( { newline). This avoids firing
  // on commands that merely mention the string (echo, grep, comments, etc.).
  if (!/(?:^|[\n;&|({])\s*git\s+push\b/.test(command)) {
    process.exit(0); // not an actual git push invocation
  }

  const cwd = payload.cwd || process.cwd();
  process.stderr.write("pre-push: running luau type check (npm run lint:luau)...\n");

  const res = spawnSync("npm run lint:luau", {
    cwd,
    shell: true,
    encoding: "utf8",
  });

  if (res.status !== 0) {
    process.stderr.write(
      "pre-push: luau type check FAILED. Push blocked. Fix these first:\n" +
        (res.stdout || "") +
        (res.stderr || ""),
    );
    process.exit(2);
  }
  process.exit(0);
});
