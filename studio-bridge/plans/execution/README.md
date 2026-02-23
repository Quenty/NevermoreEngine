# Execution Plan: Studio-Bridge Persistent Sessions

This directory contains the execution plan for building persistent sessions into studio-bridge. The plan is split into per-phase files covering tasks, dependencies, acceptance criteria, testing strategy, risk mitigation, and sub-agent assignment. Each phase maps to one or more tech specs and is scoped tightly enough to be handed to a developer or AI agent with clear acceptance criteria.

References:
- PRD: `studio-bridge/plans/prd/main.md`
- Tech spec overview: `studio-bridge/plans/tech-specs/00-overview.md`
- Protocol: `studio-bridge/plans/tech-specs/01-protocol.md`
- Command system: `studio-bridge/plans/tech-specs/02-command-system.md`
- Persistent plugin: `studio-bridge/plans/tech-specs/03-persistent-plugin.md`
- Action specs: `studio-bridge/plans/tech-specs/04-action-specs.md`
- Split server mode: `studio-bridge/plans/tech-specs/05-split-server.md`
- MCP server: `studio-bridge/plans/tech-specs/06-mcp-server.md`
- Bridge Network layer: `studio-bridge/plans/tech-specs/07-bridge-network.md`
- Host failover: `studio-bridge/plans/tech-specs/08-host-failover.md`
- Output modes: `studio-bridge/plans/execution/output-modes-plan.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## Reading Order

1. **Start with `phases/`** to understand what gets built in each phase -- tasks, dependencies, acceptance criteria, and testing strategy.
2. **Use `agent-prompts/`** when assigning tasks to sub-agents. Each file contains self-contained prompts for automatable tasks and handoff notes for tasks requiring orchestrator coordination or review.
3. **Use `validation/`** to understand acceptance criteria and test plans -- unit tests, integration tests, e2e tests, phase gates, regression tests, performance tests, and security tests.
4. **`output-modes-plan.md`** is a standalone detailed design for Phase 0 (output mode utilities). It lives at the top level because it modifies `tools/cli-output-helpers/`, not `tools/studio-bridge/`.

---

## Phase-to-Tech-Spec Mapping

| Phase | Execution file | Primary tech specs |
|-------|---------------|-------------------|
| 0 | `phases/00-prerequisites.md` | (no tech spec -- see `output-modes-plan.md`) |
| 0.5 | `phases/00.5-plugin-modules.md` | `01-protocol.md`, `03-persistent-plugin.md`, `04-action-specs.md` |
| 1 | `phases/01-bridge-network.md` | `07-bridge-network.md`, `01-protocol.md`, `02-command-system.md` |
| 1b | `phases/01b-failover.md` | `08-host-failover.md` |
| 2 | `phases/02-plugin.md` | `03-persistent-plugin.md`, `04-action-specs.md` |
| 3 | `phases/03-commands.md` | `04-action-specs.md`, `02-command-system.md` |
| 4 | `phases/04-split-server.md` | `05-split-server.md` |
| 5 | `phases/05-mcp-server.md` | `06-mcp-server.md` |
| 6 | `phases/06-integration.md` | `00-overview.md` (architecture) |

---

## Phase Dependencies

The longest dependency chain determines the minimum number of sequential steps to reach a fully functional system:

```
Phase 0.5 (plugin modules) --+
                              +--> 2.1 (Layer 2 glue)
1.1 (protocol v2) -----------+       |
  -> 1.5 (v2 handshake)              +--> 2.2 (execute action)
    -> 1.6 (action dispatch)               +--> 2.5 (detection + fallback)
                                                  +--> 3.1-3.4 (new actions) <- needs 1.7a + 1.7b + 2.1
                                                        +--> 3.5 (wire terminal adapter)
                                                              +--> 5.1 (MCP scaffold)
                                                                    +--> 5.2 (MCP tools)
                                                                          +--> 6.2 (e2e tests)
```

Key dependency rules:

- **Phase 0 and Phase 0.5 are independent** of each other and of Phase 1. Both can run in parallel with everything. Phase 0 modifies `tools/cli-output-helpers/`. Phase 0.5 creates pure Luau modules testable via Lune.
- **Phase 1 core (Tasks 1.1-1.7b)** is independent of Phase 0 (except Task 1.7a needs Phase 0 for output mode utilities). Phase 1 core does NOT include failover -- basic `SessionDisconnectedError` handling is in Task 1.3b.
- **Task 1.3d has been split into 5 subtasks (1.3d1-1.3d5).** Subtasks 1.3d1-1.3d4 are agent-assignable and run in sequence (each builds on the previous). Subtask 1.3d5 (barrel export and API surface review) is a review checkpoint (~30 minutes) that a review agent or the orchestrator can verify against the tech spec checklist. The orchestrator should dispatch 1.3d1-1.3d4 to agents after Wave 2 completes, then dispatch 1.3d5 to a review agent. Do NOT dispatch Wave 3.5+ tasks until 1.3d5 is validated and merged. Other Wave 3 tasks that do not depend on 1.3d (0.5.4, 1.6, 2.1) may continue in parallel.
- **Phase 1b (failover: Tasks 1.8-1.10)** depends only on Task 1.3a. It runs in parallel with Phases 2-3 and is NOT a gate for them.
- **Phase 2 depends on Phase 0.5** (Layer 1 plugin modules) **+ Phase 1 core**. Task 2.1 needs Phase 0.5 for the pure Luau modules and Task 1.1 for message format. Task 2.6 needs Tasks 1.3, 1.4, and 1.7a.
- **Phase 3 depends on Tasks 1.7a + 1.7b + 2.1.** Task 1.7b (reference `sessions` command) establishes the pattern that Phase 3 commands follow.
- **Phase 4 depends only on Phase 1 core** (bridge module). It can proceed in parallel with Phases 2-3. **Tasks 4.2, 4.3, and 6.5 must be sequential** (4.2 -> 4.3 -> 6.5) because all three modify `bridge-connection.ts`. Do NOT run them in parallel.
- **Phase 5 depends on Phase 3** (all command handlers must exist before the MCP adapter can wrap them). Phase 5 also extracts reusable MCP utilities (Task 1.7c) from the sessions command pattern.
- **Phase 6 (Studio E2E, human)** depends on all prior phases. Manual Studio verification is consolidated here. Task 6.5 (CI integration) has an additional dependency on Task 4.3 due to the `bridge-connection.ts` sequential chain.

**Tasks that block the most downstream work**:
1. **Task 1.1 (protocol v2)** -- blocks everything in Phases 2, 3, and 5.
2. **Task 1.3 (bridge module)** -- blocks Task 1.4 (StudioBridge wrapper), Tasks 1.7a-1.7b (CLI utilities + reference command), all of Phase 4 (split server), Task 2.3 (health endpoint), and Task 2.6 (exec/run refactor). This is the largest foundation task. **Task 1.3d has been split into 5 subtasks**: 1.3d1-1.3d4 are agent-assignable; 1.3d5 (barrel export review, ~30 min) is a review checkpoint verifiable by a review agent.
3. **Tasks 1.7a + 1.7b (shared CLI utilities + reference command)** -- blocks all command implementations in Phases 2-3 (2.6, 3.1-3.4) and the MCP adapter (5.2).
4. **Task 1.6 (action dispatch)** -- blocks all action implementations in Phase 3.
5. **Phase 0.5 (plugin modules)** -- blocks Task 2.1 (Layer 2 glue). However, Phase 0.5 has no upstream dependencies so it can start immediately.
6. **Task 2.1 (plugin Layer 2 glue)** -- blocks all plugin-side action handlers.

Tasks 1.1, 1.3, 0.1-0.4, and 0.5.1-0.5.3 should be prioritized above all others and can all proceed in parallel.

For the full critical path analysis, risk mitigation strategies, and sub-agent assignment recommendations, see `phases/06-integration.md`.

---

## Cross-Task File Modification Index

This table maps each source file to the tasks that create or modify it. Use it to identify merge conflict risks (files modified by multiple tasks), scheduling constraints (tasks that share files must be sequenced), and to quickly find which task is responsible for a given file.

All paths are relative to `/workspaces/NevermoreEngine/tools/studio-bridge/` unless otherwise noted. Paths prefixed with `(plugin)` are relative to `templates/studio-bridge-plugin/`. Paths prefixed with `(cli-helpers)` are relative to `tools/cli-output-helpers/`.

### Phase 0 -- Output mode utilities

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `(cli-helpers) src/output-modes/table-formatter.ts` | 0.1 | |
| `(cli-helpers) src/output-modes/table-formatter.test.ts` | 0.1 | |
| `(cli-helpers) src/output-modes/json-formatter.ts` | 0.2 | |
| `(cli-helpers) src/output-modes/json-formatter.test.ts` | 0.2 | |
| `(cli-helpers) src/output-modes/watch-renderer.ts` | 0.3 | |
| `(cli-helpers) src/output-modes/watch-renderer.test.ts` | 0.3 | |
| `(cli-helpers) src/output-modes/output-mode.ts` | 0.4 | |
| `(cli-helpers) src/output-modes/output-mode.test.ts` | 0.4 | |
| `(cli-helpers) src/output-modes/index.ts` | 0.4 | |

### Phase 0.5 -- Lune-testable plugin modules

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `(plugin) test/roblox-mocks.luau` | 0.5.1 | |
| `(plugin) test/test-runner.luau` | 0.5.1 | |
| `(plugin) src/Shared/Protocol.luau` | 0.5.1 | |
| `(plugin) test/protocol.test.luau` | 0.5.1 | |
| `(plugin) src/Shared/DiscoveryStateMachine.luau` | 0.5.2 | |
| `(plugin) test/discovery.test.luau` | 0.5.2 | |
| `(plugin) src/Shared/ActionRouter.luau` | 0.5.3 | |
| `(plugin) src/Shared/MessageBuffer.luau` | 0.5.3 | |
| `(plugin) test/actions.test.luau` | 0.5.3 | |
| `(plugin) test/integration/lune-bridge.test.luau` | 0.5.4 | |

### Phase 1 -- Foundation (bridge networking, protocol, CLI utilities)

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `src/server/web-socket-protocol.ts` | -- | 1.1 |
| `src/server/pending-request-map.ts` | 1.2 | |
| `src/server/pending-request-map.test.ts` | 1.2 | |
| `src/bridge/internal/transport-server.ts` | 1.3a | |
| `src/bridge/internal/bridge-host.ts` | 1.3a | 1.8, 1.10 |
| `src/bridge/internal/health-endpoint.ts` | 1.3a | 1.10 |
| `src/bridge/internal/bridge-host.test.ts` | 1.3a | |
| `src/bridge/internal/transport-server.test.ts` | 1.3a | |
| `src/bridge/internal/session-tracker.ts` | 1.3b | |
| `src/bridge/bridge-session.ts` | 1.3b | 1.8 |
| `src/bridge/types.ts` | 1.3b | |
| `src/bridge/internal/session-tracker.test.ts` | 1.3b | |
| `src/bridge/bridge-session.test.ts` | 1.3b | |
| `src/bridge/internal/bridge-client.ts` | 1.3c | 1.8, 1.10 |
| `src/bridge/internal/host-protocol.ts` | 1.3c | |
| `src/bridge/internal/transport-client.ts` | 1.3c | |
| `src/bridge/internal/bridge-client.test.ts` | 1.3c | |
| `src/bridge/internal/transport-client.test.ts` | 1.3c | |
| `src/bridge/bridge-connection.ts` | 1.3d1 | 1.3d2, 1.3d3, 1.3d4, 1.10, 2.5, 4.2, 4.3, 6.5 |
| `src/bridge/internal/environment-detection.ts` | 1.3d1 | 4.3 |
| `src/bridge/bridge-connection.test.ts` | 1.3d1 | |
| `src/bridge/internal/environment-detection.test.ts` | 1.3d1 | |
| `src/bridge/index.ts` | 1.3d5 | |
| `src/index.ts` | -- | 1.4, 6.4 |
| `src/server/studio-bridge-server.ts` | -- | 1.5, 1.6 |
| `src/server/action-dispatcher.ts` | 1.6 | |
| `src/cli/resolve-session.ts` | 1.7a | |
| `src/cli/format-output.ts` | 1.7a | |
| `src/cli/types.ts` | 1.7a | |
| `src/cli/resolve-session.test.ts` | 1.7a | |
| `src/commands/sessions.ts` | 1.7b | 1.10 |
| `src/commands/index.ts` | 1.7b | 2.4, 2.6, 3.1, 3.2, 3.3, 3.4, 4.1, 5.1 |
| `src/cli/commands/sessions-command.ts` | 1.7b | |
| `src/cli/cli.ts` | -- | 1.7b, 2.6 |

### Phase 1b -- Failover

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `src/bridge/internal/hand-off.ts` | 1.8 | 1.10 |
| `src/bridge/internal/hand-off.test.ts` | 1.8 | |
| `src/bridge/internal/__tests__/failover-graceful.test.ts` | 1.9 | |
| `src/bridge/internal/__tests__/failover-crash.test.ts` | 1.9 | |
| `src/bridge/internal/__tests__/failover-plugin-reconnect.test.ts` | 1.9 | |
| `src/bridge/internal/__tests__/failover-inflight.test.ts` | 1.9 | |
| `src/bridge/internal/__tests__/failover-timing.test.ts` | 1.9 | |

### Phase 2 -- Persistent plugin

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `(plugin) src/StudioBridgePlugin.server.lua` | -- | 2.1, 3.3 |
| `(plugin) src/Actions/` (directory) | 2.1 | |
| `(plugin) default.project.json` | -- | 2.1 |
| `(plugin) src/Actions/ExecuteAction.lua` | 2.1 | 2.2 |
| `src/plugins/plugin-manager.ts` | 2.4 | |
| `src/plugins/plugin-template.ts` | 2.4 | |
| `src/plugins/plugin-discovery.ts` | 2.4 | |
| `src/plugins/types.ts` | 2.4 | |
| `src/plugins/index.ts` | 2.4 | |
| `src/commands/install-plugin.ts` | 2.4 | |
| `src/commands/uninstall-plugin.ts` | 2.4 | |
| `src/plugin/plugin-injector.ts` | -- | 2.4, 2.5 |
| `src/commands/exec.ts` | 2.6 | |
| `src/commands/run.ts` | 2.6 | |
| `src/commands/launch.ts` | 2.6 | |
| `src/cli/args/global-args.ts` | -- | 2.6, 4.2 |
| `src/cli/commands/exec-command.ts` | -- | 2.6 |
| `src/cli/commands/run-command.ts` | -- | 2.6 |
| `src/cli/commands/terminal/terminal-mode.ts` | -- | 2.6, 3.5 |

### Phase 3 -- New action commands

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `(plugin) src/Actions/StateAction.lua` | 3.1 | |
| `src/server/actions/query-state.ts` | 3.1 | |
| `src/commands/state.ts` | 3.1 | |
| `(plugin) src/Actions/ScreenshotAction.lua` | 3.2 | |
| `src/server/actions/capture-screenshot.ts` | 3.2 | |
| `src/commands/screenshot.ts` | 3.2 | |
| `(plugin) src/Actions/LogAction.lua` | 3.3 | |
| `src/server/actions/query-logs.ts` | 3.3 | |
| `src/commands/logs.ts` | 3.3 | |
| `(plugin) src/Actions/DataModelAction.lua` | 3.4 | |
| `(plugin) src/ValueSerializer.lua` | 3.4 | |
| `src/server/actions/query-datamodel.ts` | 3.4 | |
| `src/commands/query.ts` | 3.4 | |
| `src/commands/connect.ts` | 3.5 | |
| `src/commands/disconnect.ts` | 3.5 | |
| `src/cli/commands/terminal/terminal-editor.ts` | -- | 3.5 |

### Phase 4 -- Split server mode

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `src/commands/serve.ts` | 4.1 | |

Note: Tasks 4.2 and 4.3 modify files listed in Phase 1 (`bridge-connection.ts`, `environment-detection.ts`, `global-args.ts`). See the Phase 1 and Phase 2 tables for those entries.

### Phase 5 -- MCP integration

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `src/mcp/mcp-server.ts` | 5.1 | 5.3 |
| `src/mcp/index.ts` | 5.1 | |
| `src/commands/mcp.ts` | 5.1 | |
| `package.json` | -- | 5.1 |
| `src/mcp/adapters/mcp-adapter.ts` | 5.2 | |

### Phase 6 -- Polish and integration

| Source File | Created By | Modified By |
|-------------|-----------|-------------|
| `src/server/studio-bridge-server.test.ts` | -- | 6.1 |
| `src/server/web-socket-protocol.test.ts` | -- | 6.1 |
| `src/test/e2e/persistent-session.test.ts` | 6.2 | |
| `src/test/e2e/split-server.test.ts` | 6.2 | |
| `src/test/e2e/hand-off.test.ts` | 6.2 | |
| `src/test/helpers/mock-plugin-client.ts` | 6.2 | |

Note: Tasks 6.4 and 6.5 modify files listed in Phase 1 (`index.ts`, `bridge-connection.ts`). See the Phase 1 table for those entries.

### High-contention files (modified by 3+ tasks)

These files are the most likely merge conflict sources and require careful sequencing:

| Source File | All Tasks | Scheduling Constraint |
|-------------|-----------|----------------------|
| `src/bridge/bridge-connection.ts` | Created: 1.3d1. Modified: 1.3d2, 1.3d3, 1.3d4, 1.10, 2.5, 4.2, 4.3, 6.5 | 1.3d1-1.3d4 are sequential. 4.2 -> 4.3 -> 6.5 are sequential. Other modifications must be sequenced by the orchestrator. |
| `src/commands/index.ts` | Created: 1.7b. Modified: 2.4, 2.6, 3.1, 3.2, 3.3, 3.4, 4.1, 5.1 | Append-only barrel file -- designed for auto-mergeable parallel edits. |
| `src/server/studio-bridge-server.ts` | Modified: 1.5, 1.6 | 1.5 must complete before 1.6 (dependency). |
| `src/cli/cli.ts` | Modified: 1.7b, 2.6 | 1.7b must complete before 2.6 (dependency). |
| `src/bridge/internal/bridge-host.ts` | Created: 1.3a. Modified: 1.8, 1.10 | 1.8 depends on 1.3a. 1.10 depends on 1.8. |
| `(plugin) src/StudioBridgePlugin.server.lua` | Modified: 2.1, 3.3 | 2.1 must complete before 3.3 (dependency via 2.2 -> 2.5). |

---

## How to Use Agent Prompts

Each file in `agent-prompts/` contains self-contained prompts that can be copy-pasted directly to a sub-agent (AI or human). The prompts follow these conventions:

- **One prompt per task** -- each prompt is scoped to a single task from the execution plan.
- **Context block** -- every prompt starts with the relevant tech spec references and file paths so the agent has full context without needing the rest of the plan.
- **Acceptance criteria** -- every prompt ends with the acceptance criteria from the execution plan so the agent knows exactly what "done" looks like.
- **Handoff notes** -- for tasks that require orchestrator coordination, a review agent, or Roblox Studio validation, the file includes brief handoff notes instead of full prompts. These describe what needs to happen and any real constraints (e.g., Studio runtime testing).

To assign a task:
1. Open the agent-prompts file for the relevant phase (e.g., `agent-prompts/01-bridge-network.md`).
2. Copy the prompt for the specific task you want to assign.
3. Verify the task's dependencies are complete (check the phase file for the dependency graph).
4. Paste the prompt to the sub-agent along with any additional context about the current state of the codebase.

---

## Execution Model: 2-Agent Split with Sync Points

This plan is designed for exactly 2 concurrent agents. Do NOT run more than 2 sub-agents -- merge overhead and conflict risk exceed the parallelism gain above 2 agents. File ownership boundaries between the two agents eliminate merge conflicts entirely.

**Agent A** (TypeScript infrastructure) owns `src/bridge/`, `src/server/`, `src/mcp/`, and `tools/cli-output-helpers/`. Agent A builds the protocol types, bridge networking layer, transport, health endpoint, split server mode, and MCP integration.

**Agent B** (Luau plugin + CLI commands) owns `templates/`, `src/commands/`, `src/cli/`, and `src/plugins/`. Agent B builds the Lune-testable plugin modules, failover, plugin wiring, CLI commands, and integration polish.

### Sync points

There are 6 sync points where Agent A's output unblocks Agent B. At each sync point, the orchestrator merges both agents' branches and runs `npm run test` on the merged result before Agent B proceeds. This catches "works in isolation, fails combined" issues early.

1. **SP-1: After 1.1 (protocol types)** -- B can use types in plugin modules
2. **SP-2: After 1.3a (transport)** -- B can start Lune integration tests and failover
3. **SP-3: After 1.3d5 (BridgeConnection)** -- B can start plugin wiring (Phase 2). Subtasks 1.3d1-1.3d4 are agent-assignable; 1.3d5 (barrel export review, ~30 min) is a review checkpoint verified by a review agent.
4. **SP-4: After 1.7a + 1.7b (shared utils + reference command)** -- B can start action commands (Phase 3)
5. **SP-5: After 2.3 (health endpoint)** -- B can integrate plugin discovery
6. **SP-6: After Phase 4** -- B can add devcontainer-aware behavior to CLI

For the full sync point table, realistic parallelism per wave, post-merge validation procedures, and failure recovery steps, see `TODO.md` under "Two-agent execution model", "Sync points", and "Post-merge validation".

---

## Cross-References

### Phase files
- `phases/00-prerequisites.md` -- Phase 0: Output mode utilities
- `phases/00.5-plugin-modules.md` -- Phase 0.5: Lune-testable plugin modules (pure Luau, no Roblox deps)
- `phases/01-bridge-network.md` -- Phase 1: Foundation (bridge networking, protocol, CLI utilities, reference command)
- `phases/01b-failover.md` -- Phase 1b: Failover (decoupled from Phase 1 gate, runs in parallel with Phases 2-3)
- `phases/02-plugin.md` -- Phase 2: Persistent plugin (Layer 2 glue) + installer + exec/run refactor
- `phases/03-commands.md` -- Phase 3: New action commands (state, screenshot, logs, query)
- `phases/04-split-server.md` -- Phase 4: Split server / devcontainer support
- `phases/05-mcp-server.md` -- Phase 5: MCP integration
- `phases/06-integration.md` -- Phase 6: Studio E2E (human), polish, migration + critical path + risk mitigation + sub-agent assignment

### Agent prompts
- `agent-prompts/00-prerequisites.md`
- `agent-prompts/01-bridge-network.md`
- `agent-prompts/02-plugin.md`
- `agent-prompts/03-commands.md`
- `agent-prompts/04-split-server.md`
- `agent-prompts/05-mcp-server.md`
- `agent-prompts/06-integration.md`

### Validation
- `validation/01-bridge-network.md`
- `validation/02-plugin.md`
- `validation/03-commands.md`
- `validation/04-split-server.md`
- `validation/05-mcp-server.md`
- `validation/06-integration.md`

### Standalone
- `output-modes-plan.md` -- Phase 0 detailed design
