#!/usr/bin/env node
// Action-scoping test helper. Mirrors triggers.js but tests internal behavior: given the LIVE
// SKILL.md, does an agent following it reach for the package planner (whole-package only) or
// convert directly (single file / scoped node), and never run the eval harness as part of a job?
//   tooling.js prompt            -> print the batched judge prompt (full SKILL.md + cases)
//   tooling.js score <respFile>  -> parse judge reply, score vs expected, print table, exit 1 on fail
const fs = require("fs");
const path = require("path");
const HERE = __dirname;
const SKILL = path.join(HERE, "..", "..", "SKILL.md");
const MANIFEST = path.join(HERE, "..", "tooling.json");
const cases = JSON.parse(fs.readFileSync(MANIFEST, "utf8")).cases;

if (process.argv[2] === "prompt") {
  const numbered = cases.map((c, i) => `${i + 1}. ${c.prompt}`).join("\n");
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
${fs.readFileSync(SKILL, "utf8")}
-----

Tasks:
${numbered}

Output ONLY a compact JSON array, one object per task, no prose, no code fences:
[{"n":1,"action":"direct"},{"n":2,"action":"planner"}, ...]
`);
  process.exit(0);
}

if (process.argv[2] === "score") {
  const raw = fs.readFileSync(process.argv[3], "utf8");
  const arr = JSON.parse(raw.slice(raw.indexOf("["), raw.lastIndexOf("]") + 1));
  const got = new Map(arr.map((o) => [o.n, String(o.action || "").toLowerCase()]));
  let fails = 0;
  const pad = (s, n) => String(s).padEnd(n);
  console.log(pad("#", 3) + pad("TAG", 18) + pad("EXPECT", 9) + pad("GOT", 9) + "VERDICT  PROMPT");
  cases.forEach((c, i) => {
    const n = i + 1, g = got.get(n), ok = g === c.expect;
    if (!ok) fails++;
    console.log(pad(n, 3) + pad(c.tag, 18) + pad(c.expect, 9) + pad(g || "?", 9) +
      (ok ? "ok      " : "MISS    ") + c.prompt.slice(0, 50));
  });
  console.log("");
  if (fails === 0) console.log(`TOOLING-SCOPE TEST: all ${cases.length} cases correct`);
  else { console.log(`TOOLING-SCOPE TEST: ${fails}/${cases.length} MISCLASSIFIED`); process.exit(1); }
  process.exit(0);
}

console.error("usage: tooling.js prompt | score <respFile>");
process.exit(2);
