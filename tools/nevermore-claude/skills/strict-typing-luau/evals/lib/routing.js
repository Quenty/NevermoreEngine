#!/usr/bin/env node
// Mechanical (no-LLM) eval: plan.js's MODEL ROUTING heuristic. Guards the rule that a node needing
// the full class treatment (export type + dot-syntax methods) goes to opus, a plain util to sonnet.
//
// The regression this catches: a ServiceBag service is a PLAIN table (`.ServiceName`, no
// `setmetatable`), so a naive `isClass = /setmetatable/` check mis-routes it to sonnet — which
// produced a shallow conversion (colon syntax, no export type) that broke a downstream consumer.
// plan.js therefore also treats `.ServiceName` as class-grade. This test asserts that, by reading
// plan.js's ACTUAL `isClass` predicate (so it can't silently drift) and applying plan.js's own
// model rule. No fixtures, no git, no model call — pure and fast.
const fs = require('fs');
const path = require('path');

const planPath = path.join(
  __dirname,
  '..',
  '..',
  '..',
  '..',
  'bin',
  'nevermore-strict-plan'
);
const src = fs.readFileSync(planPath, 'utf8');

// Pull the real `isClass:` expression straight out of plan.js (single source of truth).
const m = src.match(/isClass:\s*([^\n]+?),\s*\n/);
if (!m) {
  console.error(
    'FAIL: could not locate the `isClass:` predicate in plan.js — did its shape change?'
  );
  process.exit(1);
}
const isClass = new Function('src', `return (${m[1]});`);
// plan.js model rule (kept in sync with modelFor): a unit is opus if any target isClass/usesRx, or
// the unit is a cyclic cluster (>1 file). For a single-file, non-Rx node, model is decided by isClass.
const modelOf = (text, usesRx = false, clusterSize = 1) =>
  isClass(text) || usesRx || clusterSize > 1 ? 'opus' : 'sonnet';

const cases = [
  {
    name: 'ServiceBag service (.ServiceName, no setmetatable)',
    src: 'local X = {}\nX.ServiceName = "X"\nfunction X.Init(self, serviceBag) end',
    isClass: true,
    model: 'opus',
  },
  {
    name: 'ServiceBag service, tabs/extra spaces before =',
    src: 'local X = {}\nX.ServiceName\t=  "X"\n',
    isClass: true,
    model: 'opus',
  },
  {
    name: 'metatable class',
    src: 'local C = setmetatable({}, Base)\nC.__index = C',
    isClass: true,
    model: 'opus',
  },
  {
    name: 'plain util / data module',
    src: 'local Utils = {}\nfunction Utils.foo(x: number): number\n\treturn x\nend\nreturn Utils',
    isClass: false,
    model: 'sonnet',
  },
  {
    name: 'util that merely mentions ServiceName in a string/comment (not an assignment)',
    src: 'local Utils = {}\n-- returns the ServiceName for a tag\nfunction Utils.nameFor() return "ServiceName" end',
    isClass: false,
    model: 'sonnet',
  },
];

let fails = 0;
for (const c of cases) {
  const gotClass = isClass(c.src);
  const gotModel = modelOf(c.src);
  const ok = gotClass === c.isClass && gotModel === c.model;
  if (!ok) fails++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${c.name}`);
  if (!ok)
    console.log(
      `        isClass: got ${gotClass} want ${c.isClass} | model: got ${gotModel} want ${c.model}`
    );
}
console.log('');
if (fails) {
  console.log(`ROUTING TEST: ${fails}/${cases.length} FAILED`);
  process.exit(1);
}
console.log(`ROUTING TEST: all ${cases.length} cases passed`);
