#!/usr/bin/env node
// Execution-strategy test helper. Mirrors tooling.js: given the LIVE SKILL.md, does an agent
// following it fan out parallel sub-agents (package > ~3 files) or convert sequentially?
//   parallelism.js prompt            -> print the batched judge prompt (full SKILL.md + cases)
//   parallelism.js score <respFile>  -> parse judge reply, score vs expected, print table, exit 1 on fail
const fs = require("fs");
const path = require("path");
const HERE = __dirname;
const SKILL = path.join(HERE, "..", "..", "SKILL.md");
const cases = JSON.parse(fs.readFileSync(path.join(HERE, "..", "parallelism.json"), "utf8")).cases;

if (process.argv[2] === "prompt") {
  const numbered = cases.map((c, i) => `${i + 1}. ${c.prompt}`).join("\n");
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
${fs.readFileSync(SKILL, "utf8")}
-----

Tasks:
${numbered}

Output ONLY a compact JSON array, one object per task, no prose, no code fences:
[{"n":1,"action":"sequential"},{"n":2,"action":"parallel"}, ...]
`);
  process.exit(0);
}

if (process.argv[2] === "score") {
  const raw = fs.readFileSync(process.argv[3], "utf8");
  const arr = JSON.parse(raw.slice(raw.indexOf("["), raw.lastIndexOf("]") + 1));
  const got = new Map(arr.map((o) => [o.n, String(o.action || "").toLowerCase()]));
  let fails = 0;
  const pad = (s, n) => String(s).padEnd(n);
  console.log(pad("#", 3) + pad("TAG", 18) + pad("EXPECT", 12) + pad("GOT", 12) + "VERDICT  PROMPT");
  cases.forEach((c, i) => {
    const n = i + 1, g = got.get(n), ok = g === c.expect;
    if (!ok) fails++;
    console.log(pad(n, 3) + pad(c.tag, 18) + pad(c.expect, 12) + pad(g || "?", 12) +
      (ok ? "ok      " : "MISS    ") + c.prompt.slice(0, 48));
  });
  console.log("");
  if (fails === 0) console.log(`PARALLELISM TEST: all ${cases.length} cases correct`);
  else { console.log(`PARALLELISM TEST: ${fails}/${cases.length} MISCLASSIFIED`); process.exit(1); }
  process.exit(0);
}

console.error("usage: parallelism.js prompt | score <respFile>");
process.exit(2);
