#!/usr/bin/env node
// Execution-strategy test helper. Mirrors tooling.js: given the LIVE SKILL.md, does an agent
// following it fan out parallel sub-agents (package > ~3 files) or convert sequentially?
//   parallelism.js prompt            -> print the batched judge prompt (full SKILL.md + cases)
//   parallelism.js score <respFile>  -> parse judge reply, score vs expected, print table, exit 1 on fail
const judge = require("./judge.js");
const cases = judge.loadCases("parallelism");

if (process.argv[2] === "prompt") {
  process.stdout.write(
`You simulate an agent that has loaded the strict-typing-luau skill (full text below) and is handed a
task. For each task, decide HOW the skill directs the agent to EXECUTE it:
  "parallel"   = fan out multiple sub-agents concurrently — one per independent file within a
                 dependency layer — to convert several files at once.
  "sequential" = convert the file(s) one at a time, no sub-agent fan-out.

Rule the skill intends: fan out (parallel) only when a PACKAGE has more than ~3 files to convert.
A single file, a couple of named files, ~3 files, or error-fixing in one file = "sequential".

SKILL.md:
-----
${judge.readSkill()}
-----

Tasks:
${judge.numbered(cases)}

Output ONLY a compact JSON array, one object per task, no prose, no code fences:
[{"n":1,"action":"sequential"},{"n":2,"action":"parallel"}, ...]
`);
  process.exit(0);
}

if (process.argv[2] === "score") {
  const answers = judge.parseReply(process.argv[3], (reply) => String(reply.action || "").toLowerCase() || undefined);
  process.exit(judge.runScore({
    cases, answers, label: "PARALLELISM TEST",
    cols: { tag: 18, exp: 12, got: 12 }, slice: 48,
    show: (value) => value,
  }));
}

console.error("usage: parallelism.js prompt | score <respFile>");
process.exit(2);
