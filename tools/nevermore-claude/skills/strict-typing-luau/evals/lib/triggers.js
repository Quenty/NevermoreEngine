#!/usr/bin/env node
// Triggering-test helper. Two modes:
//   triggers.js prompt            -> print the batched judge prompt (live SKILL.md description + cases)
//   triggers.js score <respFile>  -> parse the judge's JSON reply, score vs expected, print table, exit 1 on fail
const fs = require('fs');
const path = require('path');
const HERE = __dirname;
const SKILL = path.join(HERE, '..', '..', 'SKILL.md');
const MANIFEST = path.join(HERE, '..', 'triggers.json');

function description() {
  const t = fs.readFileSync(SKILL, 'utf8');
  const m = t.match(/^description:\s*(.*)$/m);
  if (!m) throw new Error('no description in SKILL.md frontmatter');
  return m[1].trim();
}
const cases = JSON.parse(fs.readFileSync(MANIFEST, 'utf8')).cases;

if (process.argv[2] === 'prompt') {
  const numbered = cases.map((c, i) => `${i + 1}. ${c.prompt}`).join('\n');
  process.stdout.write(
    `You are the skill-router for an agentic coding tool working in the NevermoreEngine repo \
(a Luau/Roblox monorepo; TypeScript tooling lives under tools/). You may select AT MOST ONE \
skill per user message, and ONLY when the skill's description clearly matches the request. The \
tool also has general coding ability plus separate tooling for formatting (stylua), running \
tests, editing TypeScript, and writing docs — requests better served by those must NOT select \
a skill. Judge ONLY from the description below; do not invent capabilities.

Skill under test:
  name: strict-typing-luau
  description: ${description()}

For each user message, decide whether THIS skill should be invoked. Assume any "this file" / \
"selected file" is a Luau (.lua) source file in this repo unless the message says otherwise.

Output ONLY a compact JSON array, one object per message, no prose, no code fences:
[{"n":1,"fire":true},{"n":2,"fire":false}, ...]

Messages:
${numbered}
`
  );
  process.exit(0);
}

if (process.argv[2] === 'score') {
  const raw = fs.readFileSync(process.argv[3], 'utf8');
  const arr = JSON.parse(raw.slice(raw.indexOf('['), raw.lastIndexOf(']') + 1));
  const got = new Map(arr.map((o) => [o.n, !!o.fire]));
  let fails = 0;
  const pad = (s, n) => String(s).padEnd(n);
  console.log(
    pad('#', 3) +
      pad('TAG', 20) +
      pad('EXPECT', 8) +
      pad('GOT', 6) +
      'VERDICT  PROMPT'
  );
  cases.forEach((c, i) => {
    const n = i + 1;
    const g = got.get(n);
    const ok = g === c.expect;
    if (!ok) fails++;
    console.log(
      pad(n, 3) +
        pad(c.tag, 20) +
        pad(c.expect ? 'fire' : 'skip', 8) +
        pad(g === undefined ? '?' : g ? 'fire' : 'skip', 6) +
        (ok ? 'ok      ' : 'MISS    ') +
        c.prompt.slice(0, 52)
    );
  });
  console.log('');
  if (fails === 0)
    console.log(`TRIGGER TEST: all ${cases.length} cases correct`);
  else {
    console.log(`TRIGGER TEST: ${fails}/${cases.length} MISCLASSIFIED`);
    process.exit(1);
  }
  process.exit(0);
}

console.error('usage: triggers.js prompt | score <respFile>');
process.exit(2);
