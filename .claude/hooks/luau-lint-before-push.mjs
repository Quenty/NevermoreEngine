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
import { existsSync, statSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";

// A path argument, quoted or bare.
const PATH_ARG = `"[^"]+"|'[^']+'|\\S+`;
// Global options that may sit between `git` and the `push` subcommand, so
// `git -C <dir> push` is recognized as a push and not waved through unchecked.
const GIT_OPTS = `(?:-C\\s+(?:${PATH_ARG})\\s+|-c\\s+\\S+\\s+|--\\S+\\s+)*`;
// `git push` in command position only -- at the start of the line or right
// after a shell separator (; && || | ( { newline). This avoids firing on
// commands that merely mention the string (echo, grep, comments, etc.).
const pushRe = () => new RegExp(`(?:^|[\\n;&|({])\\s*git\\s+${GIT_OPTS}push\\b`);

// Pull the directory the push actually targets out of the command: either a
// `cd <dir>` earlier in the chain or `git -C <dir> push`. Falls back to the
// payload cwd when there is none, or when the parsed path is not a directory.
function resolvePushCwd(command, fallbackCwd) {
  const unquote = (value) => value.replace(/^["']|["']$/g, "");

  // `git -C <dir> push` wins -- it is the directory git itself will use.
  const dashC = new RegExp(
    `(?:^|[\\n;&|({])\\s*git\\s+${GIT_OPTS}-C\\s+(${PATH_ARG})\\s+${GIT_OPTS}push\\b`,
  ).exec(command);
  // Otherwise take the last `cd <dir>` that precedes the push.
  const cd = /(?:^|[\n;&|({])\s*cd\s+("[^"]+"|'[^']+'|[^\n;&|]+?)\s*(?:&&|;|\|\||\n)/g;

  let candidate;
  if (dashC) {
    candidate = unquote(dashC[1]);
  } else {
    const pushIndex = command.search(pushRe());
    for (let match = cd.exec(command); match; match = cd.exec(command)) {
      if (match.index < pushIndex) {
        candidate = unquote(match[1].trim());
      }
    }
  }

  if (!candidate) {
    return fallbackCwd;
  }

  const resolved = isAbsolute(candidate) ? candidate : resolve(fallbackCwd, candidate);
  if (existsSync(resolved) && statSync(resolved).isDirectory()) {
    return resolved;
  }
  return fallbackCwd;
}

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
  if (!pushRe().test(command)) {
    process.exit(0); // not an actual git push invocation
  }

  // Lint the tree that is actually being pushed. Pushes from a linked worktree
  // are issued as `cd <worktree> && git push ...`, but the payload cwd is always
  // the session's primary worktree -- linting that one would check the wrong
  // branch entirely.
  const cwd = resolvePushCwd(command, payload.cwd || process.cwd());
  process.stderr.write(`pre-push: running luau type check (npm run lint:luau) in ${cwd}...\n`);

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
