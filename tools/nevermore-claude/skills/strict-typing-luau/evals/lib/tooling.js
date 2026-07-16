#!/usr/bin/env node
// Action-scoping test helper. Mirrors triggers.js but tests internal behavior: given the LIVE
// SKILL.md, does an agent following it reach for the package planner (whole-package only) or
// convert directly (single file / scoped node), and never run the eval harness as part of a job?
//   tooling.js prompt            -> print the batched judge prompt (full SKILL.md + cases)
//   tooling.js score <respFile>  -> parse judge reply, score vs expected, print table, exit 1 on fail
const judge = require('./judge.js');
const cases = judge.loadCases('tooling');

if (process.argv[2] === 'prompt') {
  process.stdout.write(
    `You simulate an agent that has loaded the strict-typing-luau skill (full text below) and is handed a
task. For each task, decide what the skill directs the agent to do:
  "planner" = consult/run the package planner (\`run.sh plan <pkg>\`) and do a whole-package,
              dependency-ordered conversion.
  "direct"  = just convert the file(s) directly — single file, a scoped node ("convert only X, deps
              ready"), or fixing errors in one file. Do NOT run the planner, and never run eval-harness
              commands (gold/convert/place/score/triggers) as part of doing a conversion.

Rule the skill intends: the planner is ONLY for converting a WHOLE PACKAGE. One file, a few named
files, a scoped node, or error-fixing in a single file = "direct". When unsure, prefer "direct" —
over-orchestrating a single file is the failure we are guarding against.

SKILL.md:
-----
${judge.readSkill()}
-----

Tasks:
${judge.numbered(cases)}

Output ONLY a compact JSON array, one object per task, no prose, no code fences:
[{"n":1,"action":"direct"},{"n":2,"action":"planner"}, ...]
`
  );
  process.exit(0);
}

if (process.argv[2] === 'score') {
  const answers = judge.parseReply(
    process.argv[3],
    (reply) => String(reply.action || '').toLowerCase() || undefined
  );
  process.exit(
    judge.runScore({
      cases,
      answers,
      label: 'TOOLING-SCOPE TEST',
      cols: { tag: 18, exp: 9, got: 9 },
      slice: 50,
      show: (value) => value,
    })
  );
}

console.error('usage: tooling.js prompt | score <respFile>');
process.exit(2);
