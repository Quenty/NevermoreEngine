#!/usr/bin/env node
// Triggering-test helper. Two modes:
//   triggers.js prompt            -> print the batched judge prompt (live SKILL.md description + cases)
//   triggers.js score <respFile>  -> parse the judge's JSON reply, score vs expected, print table, exit 1 on fail
const judge = require("./judge.js");
const cases = judge.loadCases("triggers");

if (process.argv[2] === "prompt") {
  process.stdout.write(
`You are the skill-router for an agentic coding tool working in the NevermoreEngine repo \
(a Luau/Roblox monorepo; TypeScript tooling lives under tools/). You may select AT MOST ONE \
skill per user message, and ONLY when the skill's description clearly matches the request. The \
tool also has general coding ability plus separate tooling for formatting (stylua), running \
tests, editing TypeScript, and writing docs — requests better served by those must NOT select \
a skill. Judge ONLY from the description below; do not invent capabilities.

Skill under test:
  name: strict-typing-luau
  description: ${judge.description()}

For each user message, decide whether THIS skill should be invoked. Assume any "this file" / \
"selected file" is a Luau (.lua) source file in this repo unless the message says otherwise.

Output ONLY a compact JSON array, one object per message, no prose, no code fences:
[{"n":1,"fire":true},{"n":2,"fire":false}, ...]

Messages:
${judge.numbered(cases)}
`);
  process.exit(0);
}

if (process.argv[2] === "score") {
  const answers = judge.parseReply(process.argv[3], (reply) => !!reply.fire);
  process.exit(judge.runScore({
    cases, answers, label: "TRIGGER TEST",
    cols: { tag: 20, exp: 8, got: 6 }, slice: 52,
    show: (value) => (value ? "fire" : "skip"),
  }));
}

console.error("usage: triggers.js prompt | score <respFile>");
process.exit(2);
