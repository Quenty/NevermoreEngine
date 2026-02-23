# Phase 0: Prerequisites (Independent of studio-bridge)

Goal: Extend `@quenty/cli-output-helpers` with command-level output mode utilities (table formatting, JSON output, watch/follow mode) that the CLI adapter will use. These tasks modify `tools/cli-output-helpers/`, not `tools/studio-bridge/`, and can be completed in parallel with Phase 1.

Full design: `studio-bridge/plans/execution/output-modes-plan.md`

References:
- Output modes plan: `studio-bridge/plans/execution/output-modes-plan.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Detailed design: `studio-bridge/plans/execution/output-modes-plan.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/00-prerequisites.md`
- Note: Phase 0 has no validation file (tests are specified in `studio-bridge/plans/execution/output-modes-plan.md`)

---

### Task 0.1: Table formatter

**Description**: Implement `formatTable()` in `tools/cli-output-helpers/src/output-modes/table-formatter.ts`. A general-purpose utility that renders an array of objects as an aligned, colored terminal table with auto-sized columns.

**Files to create**:
- `tools/cli-output-helpers/src/output-modes/table-formatter.ts`
- `tools/cli-output-helpers/src/output-modes/table-formatter.test.ts`

**Dependencies**: None.

**Complexity**: S

**Acceptance criteria**:
- Columns auto-size to content width, with minimum width from `minWidth` or header length.
- ANSI escape codes in cell values do not break alignment (stripped for width calculation via `OutputHelper.stripAnsi`, preserved in output).
- Empty rows array produces empty string.
- Right-aligned columns pad on the left.
- Unit tests cover: basic table, empty data, ANSI colors, right alignment, custom indent.

### Task 0.2: JSON formatter

**Description**: Implement `formatJson()` in `tools/cli-output-helpers/src/output-modes/json-formatter.ts`. TTY-aware JSON formatting (pretty for TTY, compact for pipes).

**Files to create**:
- `tools/cli-output-helpers/src/output-modes/json-formatter.ts`
- `tools/cli-output-helpers/src/output-modes/json-formatter.test.ts`

**Dependencies**: None.

**Complexity**: XS

### Task 0.3: Watch renderer

**Description**: Implement `createWatchRenderer()` in `tools/cli-output-helpers/src/output-modes/watch-renderer.ts`. Extract the TTY rewrite technique from `SpinnerReporter._render()` into a reusable utility for live-updating command output.

**Files to create**:
- `tools/cli-output-helpers/src/output-modes/watch-renderer.ts`
- `tools/cli-output-helpers/src/output-modes/watch-renderer.test.ts`

**Dependencies**: None.

**Complexity**: S

### Task 0.4: Output mode selector and barrel export

**Description**: Implement `resolveOutputMode()` in `tools/cli-output-helpers/src/output-modes/output-mode.ts`. Create `output-modes/index.ts` barrel. Ensure new modules are included in the build.

**Files to create**:
- `tools/cli-output-helpers/src/output-modes/output-mode.ts`
- `tools/cli-output-helpers/src/output-modes/output-mode.test.ts`
- `tools/cli-output-helpers/src/output-modes/index.ts`

**Dependencies**: Tasks 0.1, 0.2, 0.3 (for barrel exports).

**Complexity**: XS

### Parallelization within Phase 0

Tasks 0.1, 0.2, and 0.3 have no dependencies and can proceed in parallel. Task 0.4 depends on all three for the barrel export but is trivially small.

```
0.1 (table) --------+
0.2 (json) ---------+---> 0.4 (barrel + output mode selector)
0.3 (watch) --------+
```

Phase 0 is fully independent of Phases 1-6. It modifies only `tools/cli-output-helpers/`. The output mode utilities are consumed by Task 1.7 (command handler infrastructure, specifically the CLI adapter) and by individual command handlers (Tasks 2.6, 3.1-3.4) that use `formatTable` in their `summary` composition.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 0.1 (table formatter) | ANSI stripping regex misses edge cases, breaking column alignment | Self-fix: add failing ANSI sequences to test suite and fix regex |
| 0.2 (JSON formatter) | TTY detection returns wrong value in CI or piped contexts | Self-fix: add explicit `isTTY` parameter override for testability |
| 0.3 (watch renderer) | Terminal rewrite technique does not work on all terminal emulators | Self-fix: degrade gracefully to append-only output when TERM is unsupported |
| 0.4 (barrel export) | Import paths break when consumed from `tools/studio-bridge/` | Escalate: this affects the cross-package contract between cli-output-helpers and studio-bridge; verify with the consuming package before merging |
