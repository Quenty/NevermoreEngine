#!/usr/bin/env node
// PostToolUse hook: auto-format the edited Luau file with stylua.
//
// Claude Code passes the tool event as JSON on stdin. We pull out the edited
// file path, and if it is a .lua/.luau file, run stylua on just that one file
// using the repo's stylua.toml. This removes the need to remind Claude to run
// `npm run format` after edits.
//
// Exit codes:
//   0  -> nothing to do, or formatted successfully
//   2  -> stylua reported an error (e.g. a syntax error it cannot parse);
//         stderr is fed back to Claude so it can fix the file.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";

function resolveStylua() {
  const home = os.homedir();
  const candidates = [
    path.join(home, ".aftman", "bin", "stylua.exe"),
    path.join(home, ".aftman", "bin", "stylua"),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  return "stylua"; // fall back to PATH
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch {
    process.exit(0); // no/garbled payload -> don't block the edit
  }

  const file = payload?.tool_input?.file_path;
  if (!file || !/\.luau?$/i.test(file) || !existsSync(file)) {
    process.exit(0);
  }

  const cwd = payload.cwd || process.cwd();
  const configPath = path.join(cwd, "stylua.toml");

  const res = spawnSync(
    resolveStylua(),
    ["--config-path", configPath, file],
    { encoding: "utf8" },
  );

  if (res.error) {
    // stylua not found / failed to launch -> best-effort, never block edits.
    process.exit(0);
  }
  if (res.status !== 0) {
    process.stderr.write(
      `stylua could not format ${file}:\n${res.stderr || res.stdout}\n`,
    );
    process.exit(2);
  }
  process.exit(0);
});
