# Handoff — test verdict reliability (2026-07-28/29)

Temporary. Delete once the follow-ups below are done or refiled as issues.

## Why any of this happened

CI reported ✅ on `egg-hunt-2026` while **19 tests were failing**. Not a flake — the
gate was structurally incapable of failing. Three independent faults stacked:

1. `parseTestLogs` only looked for *evidence of failure*. No logs meant no evidence
   meant pass. An empty log was a green check.
2. In batch mode the jest-failure check was skipped entirely when the log section was
   empty, so the verdict fell through to the Luau `pcall` — "the script didn't throw",
   which says nothing about tests.
3. The PR comment rendered `1 tested, 1 passed, 0 failed`. Those are **package** counts
   in test-count phrasing, with no test numbers behind them. Indistinguishable from a
   real result.

Both are fixed and merged (#772). This document is about what is *not* finished.

## Root cause of the missing logs (settled, with evidence)

**Open Cloud retains only the tail of a task's log.** The head is discarded; what
survives is one contiguous block ending at the final line.

Two 20,000-line probes plus the real suite:

| run | messages | chars | survived |
|---|---|---|---|
| probe 1 (~20 char lines) | 6,715 | ~134,300 | lines 13286–20000 |
| probe 2 (~99 char lines) | 3,237 | 297,722 | lines 16765–20000 |
| egg-hunt | 2,531 | 330,778 | tail only |

`===BATCH_TEST_BEGIN===` prints in the first moments of a run, so on any suite large
enough to overflow the window it is *always* the first casualty. That is why this
reproduced identically every time instead of flaking.

**Ruled out with evidence** — do not re-investigate these: pagination (one page, no
continuation token), a message-count cap (6,715 vs 3,237 vs 2,531), a byte cap
(134 KB vs 298 KB vs 331 KB), marker formatting, and anything in the CLI. The exact
governing unit of the window is still unknown, deliberately: **no fix should depend on
its size.**

Second, independent fault: **the API does not deliver messages in order.** Probe 1's
file began at index 13286 and ended at 16272 while containing the full range. Sorting
by `createTime` helps at second granularity but cannot order a burst — thousands of
lines share a timestamp at API precision.

## State of the work

**Merged:** #772 — verdicts require evidence; one shared rule; tracebacks always fail;
attribution by script path; unreadable output fails rather than passing.

**Open:** #773 (branch `users/quenty/batch-chunking`) — batches run in chunks of 16 so
each task's log stays inside the window. **72/73 Nevermore packages pass, up from 59.**
Also: docs name which command is the gate, and per-phase timings. Safe to merge; CI was
green before the final timing commit.

## The architectural question — answered by probe, not yet built

**The CLI is using the log as a data channel, and Open Cloud provides a real one.**

`LuauTask.output.results` is declared in `open-cloud-client.ts` ("Script return value,
populated on COMPLETE") and **read nowhere**. Probed 2026-07-29, it works:

```
[probe] task.output = {"results":["{\"probe\":\"return-channel\",\"capturedCount\":1,...}"]}
```

If `batch-test-runner.luau` *returns* the per-package summary instead of printing it,
verdicts and counts never touch the log. That subsumes nearly everything built on
2026-07-28/29: `END`-based sectioning, partial sections, the reordering guard, the
summary-array scan, chunking, and the flaky attribution below.

**Decide this before extending chunking. They are alternatives, not layers.**

Second probe result: `ScriptContext.Error` fires inside an Open Cloud task and *does*
catch deferred-callback crashes — the class jest cannot see, because they fire outside
any test. So the traceback gate can keep working while its source moves from regex to
engine events.

```
task.defer(function() error("PROBE_DEFERRED_CRASH") end)
→ capturedCount = 1, "TaskScript:16: PROBE_DEFERRED_CRASH"
```

**Caveat, unverified:** the `script` argument came back `nil` for an error raised inside
the `loadstring`'d task chunk, which is not a real `Script` instance. Errors from real
ModuleScripts should carry one — that is the shape attribution actually needs — but it
has **not** been probed. Do that before designing on it.

## Open work

| # | Item | Notes |
|---|---|---|
| 22 | Return batch results instead of printing them | Probed working. Highest payoff; decides 20/21 |
| 23 | Capture Luau errors in-engine | Probed working; ModuleScript attribution unverified |
| 14 | Thread jest config to the in-engine run | **On the critical path** — see the 300 s cap below |
| 16 | Baseline comparison | Depends on 14 |
| 21 | Packages whose END arrives out of order | Flaky false-red; superseded by 22 |
| 18 | Decide `passWithNoTests` (egg-hunt) | Deliberate for legacy packages; keep 2's rule compatible |
| 19 | **egg-hunt's 19 real test failures** | The only genuine test debt found |

### The 300 s cap is a ceiling on a single suite

egg-hunt's jest run reports `Time: 267.255 s` against a hard 300 s in-engine limit.
Chunking does **not** help — it splits *packages*, and egg-hunt is one package. When it
crosses, the task is cancelled server-side and the failure is uninformative. The only
ways out are splitting the game's specs across test targets, or scoping one suite over
several tasks, which needs #14. That is why #14 is not an ergonomics item.

### egg-hunt's failures (#19)

First readable numbers, from 2026-07-29:

```
Test Suites: 3 failed, 5 skipped, 32 passed, 35 of 40 total
Tests:       19 failed, 27 skipped, 470 passed, 516 total
```

400 raw tracebacks collapse to 5 distinct causes. First named failure:
`EggHuntPlayer datastore load failure › flags EggHuntDataStoreLoadingFailed when the
save-slot load fails`. Prior triage, now corroborated: 3 demo-area tests in
`EggHuntAccessService.spec` are order-dependent (pass alone, fail in a full run); the
other 16 fail consistently, including on `origin/main`. Suspected shared cause: raw
`player.UserId` against a `PlayerMock`, which is a Folder. `EggHuntAccessFacts.readUserId`
already has the `PlayerMock.read` fix; `PlayerBadgeHelper` → `BadgeRewardService`
(Nevermore) and `EggHuntPlayer:_logArrivalDiagnostic` do not.

## Gotchas for whoever picks this up

- **Nevermore itself has zero real test failures** under the strict rules. A large
  failure count on an `--all` sweep means *unreadable*, not *broken* — check the reason
  string before believing it.
- **`@quenty/steputils` fails intermittently** on `--all`, and the package will move
  between runs. Its `END` arrives out of order and the guard refuses to let a stray
  `END` claim a section. Fails closed, which is right, but it is noise (#21).
- **Verify against a real run, not just unit tests.** Two separate bugs this session
  passed the unit suite and were caught only by running against the real place: the
  terminal reporters keeping their own copy of the rendering, and per-phase timings
  emitting 1,095 lines of `waiting took 0ms`.
- **`npm run lint:ts` from Windows** reports "No projects matched the filters" and exits
  0, because npm shells through `cmd.exe` where single quotes are literal. CI on Ubuntu
  is fine. Use `--filter "./tools/*"` locally.

## Reproducing

```bash
# The gate command, as CI runs it
nevermore batch test --cloud --aggregated --base origin/main --yes --verbose --logs

# Full sweep (chunked, ~5m30s)
nevermore batch test --cloud --aggregated --all --yes --verbose --logs

# Probe arbitrary Luau; --logs is now on by default for this
nevermore test --cloud --script-text 'print("hi")'
```

`NO_COLOR=1` strips jest-lua's escape codes from echoed engine logs — they come from
inside Roblox and chalk never sees them.
