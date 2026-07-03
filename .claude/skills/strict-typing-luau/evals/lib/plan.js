#!/usr/bin/env node
// Compute the INTRA-PACKAGE conversion plan for a Nevermore package: the order in which to
// strict-type its files so every file is converted only after the siblings it requires.
//
//   plan.js <pkg> [json]
//     <pkg>   package dir, e.g. src/settings
//     json    emit a machine-readable plan (for a workflow driver) instead of the human table
//
// Method: edges = require("X") where X resolves to a sibling file in THIS package. Tarjan's SCC
// collapses cycles into clusters; the condensation is a DAG; Tarjan emits it in dependency-first
// order, which IS conversion order (a file's deps come before it). Each unit is either one file
// (mechanical single-file conversion) or a cyclic CLUSTER (use the cyclic-types playbook).
//
// SCOPE — deliberately intra-package only. It does NOT:
//   * order across packages (a require into another package is treated as already-typed/external)
//   * account for the downstream blast radius of high-fan-out foundational files (Maid, Promise)
// Those are a separate monorepo-level dependency problem. The plan ASSUMES cross-package deps are
// already strict (true for Maid/Promise/BaseObject/ServiceBag on main); when one isn't, that's the
// "type upstream first" case — handle it with the skill's structural-interface escape meanwhile.
const fs = require("fs");
const cp = require("child_process");
const path = require("path");

const pkg = process.argv[2];
const rest = process.argv.slice(3);
const asJson = rest.includes("json");
const evalGold = rest.includes("--eval-gold"); // eval harness only — see isTarget below
if (!pkg) { console.error("usage: plan.js <pkg> [json] [--eval-gold]"); process.exit(2); }

const listRef = evalGold ? "main" : "HEAD";
const files = cp.execSync(`git ls-tree -r --name-only ${listRef} -- ${pkg}`).toString().trim().split("\n")
  .filter((f) => f.endsWith(".lua") && !f.endsWith(".spec.lua") && !f.includes("jest.config") && !f.includes("/test/"));
if (!files.length) { console.error(`no source .lua files under ${pkg}`); process.exit(1); }

const nameToFile = {};
for (const f of files) nameToFile[path.basename(f, ".lua")] = f;

const adj = {};   // file -> [sibling files it requires]
const traits = {}; // file -> { isClass, usesRx } from a cheap source scan
for (const f of files) {
  const src = fs.readFileSync(f, "utf8");
  const reqs = [...src.matchAll(/require\("([^"]+)"\)/g)].map((m) => m[1]);
  adj[f] = [...new Set(reqs.filter((r) => nameToFile[r] && nameToFile[r] !== f).map((r) => nameToFile[r]))];
  traits[f] = {
    isClass: /setmetatable\(\{\}/.test(src),
    usesRx: reqs.some((r) => /^(Rx|RxSignal|Observable|Brio)$/.test(r)),
  };
}

// Target selection is MODE-AWARE (this is the key real-vs-eval distinction):
//   default (real conversion): target = files NOT yet --!strict in the working tree — i.e. the
//     files that actually need converting. (A package you point at is nonstrict precisely because
//     it hasn't been converted.)
//   --eval-gold (eval harness only): target = files that are --!strict on MAIN — the gold-bearing
//     set, so the eval respects exactly what the maintainer chose to convert and leaves the rest.
// Using strict-on-main as the target predicate in real mode would skip every file you asked to
// convert, so it must never be the unconditional default.
const isStrictHeader = (text) => text.split("\n", 1)[0].trim() === "--!strict";
function isTarget(f) {
  if (evalGold) {
    try { return isStrictHeader(cp.execSync(`git show main:${f}`).toString()); }
    catch (e) { return false; }
  }
  return !isStrictHeader(fs.readFileSync(f, "utf8"));
}
const skipReason = evalGold ? "nonstrict on main" : "already strict";

// Suggested worker model per unit (see README "model routing"): the precision/comprehension-heavy
// nodes go to Opus, the mechanical ones to Sonnet. Empirically Sonnet is fastest but casts to `any`
// far more, so reserve it for nodes where looseness is cheap (leaf util, no metatable, no Rx).
function modelFor(comp) {
  const tgts = comp.filter(isTarget);
  const hard = tgts.some((f) => traits[f].isClass || traits[f].usesRx) || comp.length > 1;
  return hard ? "opus" : "sonnet";
}

// Tarjan SCC — emits components in dependency-first (reverse-topological) order = conversion order.
let idx = 0;
const I = {}, low = {}, onStack = {}, stack = [], sccs = [];
function strongconnect(v) {
  I[v] = low[v] = idx++; stack.push(v); onStack[v] = true;
  for (const w of adj[v]) {
    if (I[w] === undefined) { strongconnect(w); low[v] = Math.min(low[v], low[w]); }
    else if (onStack[w]) low[v] = Math.min(low[v], I[w]);
  }
  if (low[v] === I[v]) {
    const comp = []; let w;
    do { w = stack.pop(); onStack[w] = false; comp.push(w); } while (w !== v);
    sccs.push(comp);
  }
}
for (const f of files) if (I[f] === undefined) strongconnect(f);

const rel = (f) => f.replace(`${pkg}/src/`, "");
const compIndex = {}; sccs.forEach((c, i) => c.forEach((f) => (compIndex[f] = i)));
const units = sccs.map((comp, i) => ({
  step: i + 1,
  kind: comp.length === 1 ? "single" : "cluster",
  model: modelFor(comp),
  files: comp.map(rel),
  // `targets` = the subset actually converted (mode-aware, see isTarget). The driver converts only
  // these and leaves the rest as-is. A unit with no targets is skipped entirely.
  targets: comp.filter(isTarget).map(rel),
  // external sibling deps already satisfied by earlier steps (for display only)
  needs: [...new Set(comp.flatMap((f) => adj[f]).filter((d) => compIndex[d] !== i).map(rel))],
}));

if (asJson) { process.stdout.write(JSON.stringify({ pkg, units }, null, 2) + "\n"); process.exit(0); }

const mark = (r, u) => u.targets.includes(r) ? r : `${r}  (${skipReason} — skipped)`;
const convertUnits = units.filter((u) => u.targets.length);
console.log(`${pkg}: ${files.length} source files -> ${convertUnits.length} convertible units ` +
  `(${units.length - convertUnits.length} units skipped: ${skipReason}). Dependency order:\n`);
for (const u of units) {
  if (!u.targets.length) { console.log(`${String(u.step).padStart(2)}. [skip       ] ${u.files.join(", ")}  (${skipReason})`); continue; }
  const tag = `${u.kind === "single" ? "single " : "cluster"} · ${u.model.padEnd(6)}`;
  if (u.kind === "single") console.log(`${String(u.step).padStart(2)}. [${tag}] ${mark(u.files[0], u)}`);
  else {
    console.log(`${String(u.step).padStart(2)}. [${tag}] CLUSTER — convert ${u.targets.length}/${u.files.length} (cyclic-types playbook)`);
    u.files.forEach((f) => console.log(`                      ${mark(f, u)}`));
  }
}
const onOpus = convertUnits.filter((u) => u.model === "opus").length;
console.log(`\nConvert ${convertUnits.length} units: ${onOpus} opus (class/cyclic/Rx), ${convertUnits.length - onOpus} sonnet (mechanical).`);
console.log(`Intra-package only; cross-package deps assumed already strict; ${skipReason} files left as-is.` +
  (evalGold ? "" : "  [real mode: targets = not-yet-strict files; pass --eval-gold for the harness view]"));
