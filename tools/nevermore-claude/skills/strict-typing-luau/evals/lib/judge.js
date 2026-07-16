// Shared scaffolding for the three LLM-judged skill tests (triggers / tooling / parallelism).
// Each test is the same shape: build a batched judge prompt from SKILL.md + its cases, then score
// the model's JSON reply against each case's `expect`. Only the prompt preamble and the reply field
// ("fire" bool vs "action" string) differ per test — everything mechanical lives here so the three
// entrypoints stay just their preamble.
const fs = require("fs");
const path = require("path");

const HERE = __dirname;
const SKILL = path.join(HERE, "..", "..", "SKILL.md");

const readSkill = () => fs.readFileSync(SKILL, "utf8");

function description() {
  const match = readSkill().match(/^description:\s*(.*)$/m);
  if (!match) throw new Error("no description in SKILL.md frontmatter");
  return match[1].trim();
}

const loadCases = (name) => JSON.parse(fs.readFileSync(path.join(HERE, "..", `${name}.json`), "utf8")).cases;
const numbered = (cases) => cases.map((testCase, index) => `${index + 1}. ${testCase.prompt}`).join("\n");

// Parse the judge's reply (tolerant of prose/fences around the JSON array) into caseNum -> answer,
// where `pick` pulls the per-object answer (returning undefined for a missing/empty one, shown "?").
function parseReply(respFile, pick) {
  const raw = fs.readFileSync(respFile, "utf8");
  const replies = JSON.parse(raw.slice(raw.indexOf("["), raw.lastIndexOf("]") + 1));
  return new Map(replies.map((reply) => [reply.n, pick(reply)]));
}

// Score answers against each case's expect, print the table, and return the process exit code (0/1).
// `cols` sizes the TAG/EXPECT/GOT columns; `show` renders a raw answer for display.
function runScore({ cases, answers, label, cols, slice, show }) {
  const pad = (text, width) => String(text).padEnd(width);
  let fails = 0;
  console.log(pad("#", 3) + pad("TAG", cols.tag) + pad("EXPECT", cols.exp) + pad("GOT", cols.got) + "VERDICT  PROMPT");
  cases.forEach((testCase, index) => {
    const caseNum = index + 1;
    const answer = answers.get(caseNum);
    const ok = answer === testCase.expect;
    if (!ok) fails++;
    console.log(
      pad(caseNum, 3) + pad(testCase.tag, cols.tag) + pad(show(testCase.expect), cols.exp) +
      pad(answer === undefined ? "?" : show(answer), cols.got) +
      (ok ? "ok      " : "MISS    ") + testCase.prompt.slice(0, slice)
    );
  });
  console.log("");
  if (fails === 0) { console.log(`${label}: all ${cases.length} cases correct`); return 0; }
  console.log(`${label}: ${fails}/${cases.length} MISCLASSIFIED`);
  return 1;
}

module.exports = { readSkill, description, loadCases, numbered, parseReply, runScore };
