#!/usr/bin/env node
// PostToolUse hook: auto-format the edited TypeScript/JavaScript file with prettier.
//
// Mirrors the repo's `format:ts` / `lint:prettier` scripts: only files under
// tools/ with a .ts/.tsx/.js/.jsx extension, using the root prettier config and
// --ignore-path .gitignore. Anything outside that scope is a no-op, so this hook
// never diverges from what `npm run lint:prettier` checks.
//
// Exit codes:
//   0  -> nothing to do, or formatted successfully
//   2  -> prettier reported an error (e.g. a syntax error); stderr is fed back
//         to Claude so it can fix the file.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);

function resolvePrettierBin() {
  try {
    return require.resolve("prettier/bin-prettier.js");
  } catch {
    try {
      return path.join(path.dirname(require.resolve("prettier")), "bin-prettier.js");
    } catch {
      return null;
    }
  }
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
  if (!file || !/\.(ts|tsx|js|jsx)$/i.test(file) || !existsSync(file)) {
    process.exit(0);
  }

  const cwd = payload.cwd || process.cwd();

  // Scope to tools/ only, matching `format:ts` (tools/**/*.{ts,tsx,js,jsx}).
  const rel = path.relative(cwd, file);
  if (rel.startsWith("..") || path.isAbsolute(rel)) process.exit(0);
  const top = rel.split(/[\\/]/)[0];
  if (top !== "tools") process.exit(0);

  const bin = resolvePrettierBin();
  if (!bin) process.exit(0); // prettier not installed -> best-effort, don't block.

  const res = spawnSync(
    process.execPath,
    [bin, "--ignore-path", ".gitignore", "--write", file],
    { cwd, encoding: "utf8" },
  );

  if (res.error) {
    process.exit(0); // failed to launch -> best-effort, never block edits.
  }
  if (res.status !== 0) {
    process.stderr.write(
      `prettier could not format ${file}:\n${res.stderr || res.stdout}\n`,
    );
    process.exit(2);
  }
  process.exit(0);
});
