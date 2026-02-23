# Studio Bridge — Execution TODO

> **Living document.** Update this as tasks are started, completed, or blocked.
> Last updated: 2026-02-23 (de-risking restructure: Phase 0.5 plugin modules, Phase 1b failover, 1.7 split, manual testing deferred to Phase 6)

## How to Use This Document

- A coordinator (human or AI agent) uses this to track progress and delegate work
- Check off tasks as they complete: `- [x]`
- Mark blocked tasks with `BLOCKED:` and the reason
- Mark in-progress tasks with `IN PROGRESS:` and the assignee
- When delegating to a sub-agent, reference the agent-prompt file for that phase
- After completing a phase, verify all gate criteria in the corresponding validation file
- Base path for all studio-bridge source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`
- Phase 0 modifies `tools/cli-output-helpers/`, not `tools/studio-bridge/`

---

## Status Overview

| Phase | Status | Tasks | Completed | Blocked |
|-------|--------|-------|-----------|---------|
| 0: Prerequisites (Output Modes) | Not started | 4 | 0 | 0 |
| 0.5: Plugin Modules | Not started | 4 | 0 | 0 |
| 1: Bridge Network Foundation | Not started | 15 | 0 | 0 |
| 1b: Failover | Not started | 3 | 0 | 0 |
| 2: Persistent Plugin | Not started | 6 | 0 | 0 |
| 3: New Action Commands | Not started | 5 | 0 | 0 |
| 4: Split Server Mode | Not started | 3 | 0 | 0 |
| 5: MCP Integration | Not started | 3 | 0 | 0 |
| 6: Polish & Integration | Not started | 5 | 0 | 0 |
| **Total** | | **48** | **0** | **0** |

---

## Phase 0: Prerequisites (Output Modes)

> Plan: `phases/00-prerequisites.md` | Agent prompts: `agent-prompts/00-prerequisites.md` | Validation: see `output-modes-plan.md`
> Modifies: `tools/cli-output-helpers/src/output-modes/`
> Independent of all other phases. Can run in parallel with Phase 1.

### Parallelization

```
0.1 (table) --------+
0.2 (json) ---------+---> 0.4 (barrel + output mode selector)
0.3 (watch) --------+
```

### Tasks

- [ ] **0.1** Table formatter (S)
  - File: `tools/cli-output-helpers/src/output-modes/table-formatter.ts`
  - Test: `tools/cli-output-helpers/src/output-modes/table-formatter.test.ts`
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: auto-sized columns, ANSI-safe alignment, empty rows = empty string, right-align support

- [ ] **0.2** JSON formatter (XS)
  - File: `tools/cli-output-helpers/src/output-modes/json-formatter.ts`
  - Test: `tools/cli-output-helpers/src/output-modes/json-formatter.test.ts`
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: TTY pretty-print (2-space), non-TTY compact, explicit override

- [ ] **0.3** Watch renderer (S)
  - File: `tools/cli-output-helpers/src/output-modes/watch-renderer.ts`
  - Test: `tools/cli-output-helpers/src/output-modes/watch-renderer.test.ts`
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: TTY rewrite mode, non-TTY append mode, start/stop/update lifecycle

- [ ] **0.4** Output mode selector + barrel export (XS)
  - Files: `tools/cli-output-helpers/src/output-modes/output-mode.ts`, `tools/cli-output-helpers/src/output-modes/index.ts`
  - Test: `tools/cli-output-helpers/src/output-modes/output-mode.test.ts`
  - Dependencies: 0.1, 0.2, 0.3
  - Agent-assignable: yes
  - Acceptance: `--json` -> json, TTY -> table, non-TTY -> text; barrel exports all modules

---

## Phase 0.5: Plugin Modules

> Plan: `phases/02-plugin.md` (Luau module specs) | Validation: `validation/02-plugin.md`
> Modifies: `templates/studio-bridge-plugin/src/Shared/`
> Independent of Phase 1. Can run in parallel with Phase 0 and Phase 1 (Wave 1).
> Cross-language integration test (0.5.4) depends on 1.3a for the TypeScript server side.

### Parallelization

```
0.5.1 (protocol) ------+
                        +---> 0.5.4 (Lune integration tests) [also needs 1.3a]
0.5.2 (discovery) -----+
0.5.3 (action router) -+
```

### Tasks

- [ ] **0.5.1** Protocol module (S)
  - File: `templates/studio-bridge-plugin/src/Shared/Protocol.luau`
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: Luau module encoding/decoding v2 protocol messages, round-trip tests for all message types

- [ ] **0.5.2** Discovery state machine (M)
  - File: `templates/studio-bridge-plugin/src/Shared/DiscoveryStateMachine.luau`
  - Dependencies: 0.5.1
  - Agent-assignable: yes
  - Acceptance: States: searching/connecting/connected/reconnecting, port scanning, health check, backoff with jitter, shutdown message resets to searching with zero delay

- [ ] **0.5.3** Action router + message buffer (S)
  - Files: `templates/studio-bridge-plugin/src/Shared/ActionRouter.luau`, `MessageBuffer.luau`
  - Dependencies: 0.5.1
  - Agent-assignable: yes
  - Acceptance: Route incoming action requests to registered handlers, buffer outgoing messages during reconnection, flush on reconnect

- [ ] **0.5.4** Lune integration tests (M)
  - Cross-language: Lune client + TypeScript server
  - Dependencies: 0.5.1, 0.5.2, 0.5.3, 1.3a
  - Agent-assignable: yes
  - Acceptance: Lune script drives plugin modules against a real TypeScript WebSocket server, verifies handshake round-trip, action dispatch, reconnection after drop

### Phase 0.5 Gate

- [ ] All Lune unit tests pass for Protocol, DiscoveryStateMachine, ActionRouter, MessageBuffer
- [ ] Integration round-trip works (Lune client <-> TypeScript server)

---

## Phase 1: Bridge Network Foundation

> Plan: `phases/01-bridge-network.md` | Agent prompts: `agent-prompts/01-bridge-network.md` | Validation: `validation/01-bridge-network.md`
> Failover tasks (1.8, 1.9, 1.10) have moved to Phase 1b and run in parallel with Phases 2-3.

### Parallelization

```
Phase 0 (runs in parallel):
0.1-0.3 --> 0.4 (barrel)
                |
Phase 0.5 (runs in parallel):
0.5.1 --> 0.5.2, 0.5.3 --> 0.5.4 (also needs 1.3a)

Phase 1:        |
1.1 (protocol v2) ------+
                          +---> 1.5 (v2 handshake) --> 1.6 (action dispatch)
1.2 (pending requests) --+                              ^
                                                         |
1.3a (transport + host) --+--> 1.3b (sessions) --+       |
                          |                       |        |
                          +--> 1.3c (client) -----+        |
                                                  |        |
                          1.3d1 (role detection) -+        |
                          1.3d2 (listSessions) ---+        |
                          1.3d3 (resolveSession) -+        |
                          1.3d4 (waitForSession) -+        |
                          1.3d5 (barrel) [REVIEW] -+        |
                                                  |        |
1.3d5 --> 1.4 (StudioBridge wrapper)              |        |
       --+                                        |        |
         +---> 1.7a (shared CLI utils) --> 1.7b (sessions cmd)
0.4 (barrel) --+                                           |
                                                           |
1.2 ----------------------------------------------------->-+

Phase 1b (runs in parallel with Phases 2-3):
1.3a --> 1.8 (failover impl) --> 1.9 (failover tests)
1.3d5 + 1.8 --> 1.10 (failover observability)
```

### Tasks

- [ ] **1.1** Protocol v2 type definitions (M)
  - File: `src/server/web-socket-protocol.ts` (modify)
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: all v2 message types exported, `decodePluginMessage` handles v2 types, new `decodeServerMessage` function, existing tests pass unchanged, round-trip tests for every v2 type

- [ ] **1.2** Request/response correlation layer (S)
  - File: `src/server/pending-request-map.ts` (create)
  - Test: `src/server/pending-request-map.test.ts`
  - Dependencies: none
  - Agent-assignable: yes
  - Acceptance: resolve/reject by ID, timeout, cancelAll, unknown ID is no-op

- [ ] **1.3a** Transport layer and bridge host (M) -- CRITICAL PATH
  - Files: `src/bridge/internal/transport-server.ts`, `src/bridge/internal/bridge-host.ts`, `src/bridge/internal/health-endpoint.ts` + tests
  - Dependencies: 1.1
  - Agent-assignable: yes
  - Acceptance: WebSocket server with `/plugin`, `/client`, `/health` paths; `reuseAddr: true`; port binding with clean `EADDRINUSE` reporting

- [ ] **1.3b** Session tracker and bridge session (M)
  - Files: `src/bridge/internal/session-tracker.ts`, `src/bridge/bridge-session.ts`, `src/bridge/types.ts` + tests
  - Dependencies: 1.3a
  - Agent-assignable: yes
  - Acceptance: session map with `(instanceId, context)` grouping, `SessionInfo`/`InstanceInfo` types, session lifecycle events, `BridgeSession` action dispatch

- [ ] **1.3c** Bridge client and host protocol (M)
  - Files: `src/bridge/internal/bridge-client.ts`, `src/bridge/internal/host-protocol.ts`, `src/bridge/internal/transport-client.ts` + tests
  - Dependencies: 1.3a
  - Agent-assignable: yes
  - Acceptance: WebSocket client on `/client`, `HostEnvelope`/`HostResponse` types, command forwarding through host, automatic reconnection with backoff

- [ ] **1.3d** BridgeConnection and role detection (M) -- CRITICAL PATH (split into 5 subtasks)
  - Files: `src/bridge/bridge-connection.ts`, `src/bridge/internal/environment-detection.ts`, `src/bridge/index.ts` + tests
  - Dependencies: 1.3a, 1.3b, 1.3c
  - NOTE: Blocks the most downstream work -- 1.4, 1.7a, 1.7b, Phase 1b (1.9, 1.10), all of Phase 4, 2.3, 2.6
  - **Subtasks run in sequence** (each builds on the previous). Only 1.3d5 requires a review checkpoint.
  - **ORCHESTRATOR INSTRUCTION**: Subtasks 1.3d1-1.3d4 are agent-assignable. After 1.3d4 completes, dispatch 1.3d5 to a review agent (or have the orchestrator verify the checklist). Do NOT proceed to Wave 3.5 or later until 1.3d5 is validated and merged. Other Wave 3 tasks (0.5.4, 1.6, 2.1) that do not depend on 1.3d5 may continue in parallel.

  - [ ] **1.3d1** `BridgeConnection.connectAsync()` and role detection (M)
    - Files: `src/bridge/bridge-connection.ts`, `src/bridge/internal/environment-detection.ts` + tests
    - Dependencies: 1.3a, 1.3b, 1.3c
    - Agent-assignable: **yes**
    - Acceptance: host/client auto-detection on port 38741 (try bind -> host; EADDRINUSE -> client; stale -> retry), `disconnectAsync`, idle exit with 5s grace, `role` and `isConnected` getters
    - Test: two concurrent connections on same port -> first is host, second is client

  - [ ] **1.3d2** `BridgeConnection.listSessions()` and `listInstances()` (S)
    - Files: `src/bridge/bridge-connection.ts` (modify)
    - Dependencies: 1.3d1
    - Agent-assignable: **yes**
    - Acceptance: `listSessions` returns connected plugins, `listInstances` groups by instanceId, `getSession` by ID, works in both host and client mode
    - Test: connect mock plugin, verify session appears in list

  - [ ] **1.3d3** `BridgeConnection.resolveSession()` (S)
    - Files: `src/bridge/bridge-connection.ts` (modify)
    - Dependencies: 1.3d2
    - Agent-assignable: **yes**
    - Acceptance: instance-aware resolution algorithm from tech-spec 07 section 2.1 (explicit ID, auto-select single instance, context selection, error on multiple)
    - Test: 0 sessions -> error; 1 session -> returns it; N sessions -> error with list

  - [ ] **1.3d4** `BridgeConnection.waitForSession()` and events (S)
    - Files: `src/bridge/bridge-connection.ts` (modify)
    - Dependencies: 1.3d3
    - Agent-assignable: **yes**
    - Acceptance: async wait resolves when plugin connects, rejects on timeout, session lifecycle events (session-connected, session-disconnected, instance-connected, instance-disconnected)
    - Test: call before plugin connects -> resolves when plugin connects; verify rejects on timeout

  - [ ] **1.3d5** Barrel export and API surface review (XS) -- REVIEW CHECKPOINT
    - Files: `src/bridge/index.ts` (create)
    - Dependencies: 1.3d4
    - Agent-assignable: **yes** (review agent verifies exports match tech spec)
    - Acceptance: barrel export matches tech-spec 07 section 2.1 exactly, nothing from `internal/` re-exported
    - NOTE: This is a ~30-minute review task, not a multi-hour integration review
    - **Reviewer checklist**:
      - [ ] `BridgeConnection` public API matches tech spec `07-bridge-network.md` section 2.1 signature exactly
      - [ ] No `any` casts outside constructor boundaries
      - [ ] All existing tests still pass (`cd tools/studio-bridge && npm run test`)
      - [ ] New integration test covers connect -> execute -> disconnect lifecycle
      - [ ] `StudioBridge` wrapper delegates without duplicating logic

- [ ] **1.4** Integrate BridgeConnection into StudioBridge class (S)
  - File: `src/index.ts` (modify)
  - Dependencies: 1.3d5
  - Agent-assignable: yes
  - Acceptance: `StudioBridge` API unchanged externally, internally delegates to `BridgeConnection`/`BridgeSession`, existing tests pass, new types exported from `index.ts`

- [ ] **1.5** v2 handshake support in StudioBridgeServer (S)
  - File: `src/server/studio-bridge-server.ts` (modify)
  - Dependencies: 1.1
  - Agent-assignable: yes
  - Acceptance: v1 hello = v1 welcome, v2 hello with capabilities = v2 welcome, register = v2 welcome, heartbeat tracked

- [ ] **1.6** Action dispatch on the server (M)
  - Files: `src/server/action-dispatcher.ts` (create), `src/server/studio-bridge-server.ts` (modify)
  - Dependencies: 1.1, 1.2, 1.5
  - Agent-assignable: yes
  - Acceptance: `performActionAsync` sends v2 request with `requestId`, resolves on match, rejects on timeout, rejects on plugin error, throws for v1 plugin or missing capability

- [ ] **1.7a** Shared CLI utilities (S)
  - Files: `src/cli/resolve-session.ts`, `format-output.ts`, `types.ts`
  - Dependencies: 1.3d5, Phase 0 (0.4)
  - Agent-assignable: yes
  - Acceptance: `resolveSessionAsync` handles 0/1/N sessions + explicit ID, output mode integration, shared types for command handlers

- [ ] **1.7b** Reference `sessions` command + barrel export pattern (S)
  - Files: `src/commands/sessions.ts`, `src/commands/index.ts` (barrel), `src/cli/cli.ts` (modify to loop over `allCommands`)
  - Dependencies: 1.7a
  - Agent-assignable: yes
  - Acceptance: single handler using shared CLI utils, barrel file (`src/commands/index.ts`) with `allCommands` array, `cli.ts` registers via loop over `allCommands` (never modified per-command again), table output (Session ID, Place, State, Origin, Duration), `--json`, `--watch`, helpful messages for no-host and no-sessions cases

### Phase 1 Gate

- [ ] All existing tests pass unchanged (regression)
- [ ] v2 protocol encode/decode round-trips for all message types
- [ ] PendingRequestMap all tests passing
- [ ] BridgeConnection session tracking tests passing
- [ ] `sessions` command lists sessions (1.7b)
- [ ] Gate command: `cd tools/studio-bridge && npm run test`

---

## Phase 1b: Failover

> Plan: `phases/01-bridge-network.md` | Agent prompts: `agent-prompts/01-bridge-network.md` | Validation: `validation/01-bridge-network.md`
> Runs in parallel with Phases 2-3. No longer blocks downstream work.

### Tasks

- [ ] **1.8** Bridge host failover implementation (M)
  - Files: `src/bridge/internal/hand-off.ts` (create), `src/bridge/internal/bridge-host.ts`, `src/bridge/internal/bridge-client.ts`, `src/bridge/bridge-session.ts` (modify) + `src/bridge/internal/hand-off.test.ts`
  - Dependencies: 1.3a
  - Agent-assignable: no (multi-process coordination with timing races, requires careful testing with real sockets)
  - Acceptance: graceful shutdown via SIGTERM/SIGINT, crash recovery with jitter 0-500ms, plugin reconnection with backoff, inflight requests reject with `SessionDisconnectedError`, deterministic state machine (connected/taking-over/promoted)

- [ ] **1.9** Failover integration tests (M)
  - Files: `src/bridge/internal/__tests__/failover-graceful.test.ts`, `failover-crash.test.ts`, `failover-plugin-reconnect.test.ts`, `failover-inflight.test.ts`, `failover-timing.test.ts`
  - Dependencies: 1.3d5, 1.8
  - Agent-assignable: no (integration tests with multiple concurrent processes, port binding races, timing assertions)
  - Acceptance: graceful takeover <2s, hard kill takeover <5s, TIME_WAIT recovery <1s, rapid restart <5s, exactly one host after multi-client takeover, jitter spread >100ms

- [ ] **1.10** Failover debugging and observability (S)
  - Files: `src/bridge/internal/hand-off.ts`, `bridge-host.ts`, `bridge-client.ts`, `bridge-connection.ts`, `src/commands/sessions.ts`, `health-endpoint.ts` (all modify)
  - Dependencies: 1.3d5, 1.8
  - Agent-assignable: yes
  - Acceptance: structured debug logs for state transitions, `hostUptime`/`lastFailoverAt` in health endpoint, `BridgeConnection.role` updated on promotion, recovery message during failover

### Phase 1b Gate

- [ ] Hand-off state machine unit tests passing
- [ ] All failover integration tests passing (1.9)
- [ ] Gate command: `cd tools/studio-bridge && npm run test`

---

## Phase 2: Persistent Plugin

> Plan: `phases/02-plugin.md` | Agent prompts: `agent-prompts/02-plugin.md` | Validation: `validation/02-plugin.md`
> Depends on Phase 1 (especially Tasks 1.1, 1.3d5, 1.6, 1.7a). Sessions command now in Phase 1 (1.7b).

### Parallelization

```
2.1 (plugin core) --> 2.2 (execute action) --> 2.5 (detection + fallback)
                  --> 2.4 (plugin manager)  --> 2.5
                                                  ^
2.3 (health endpoint) ----------------------------+

2.6 (exec/run refactor) -- needs 1.3d5 + 1.4 + 1.7a
```

### Tasks

- [ ] **2.1** Unified plugin -- upgrade existing template (L) -- REVIEW CHECKPOINT (requires Studio validation)
  - Files: `templates/studio-bridge-plugin/src/StudioBridgePlugin.server.lua` (modify), `Discovery.lua`, `Protocol.lua`, `ActionHandler.lua` (create), `default.project.json` (modify)
  - Dependencies: 1.1
  - Agent-assignable: no (complex Luau, requires manual testing in Studio)
  - Acceptance: boot mode detection, discovery via health check, `register` with all capabilities, fallback to `hello`, heartbeat every 15s, reconnect with backoff, `stateChange` push, ephemeral mode backward-compatible
  - **Reviewer checklist**:
    - [ ] Plugin enters `connected` state in Studio when bridge host is running
    - [ ] Plugin stays in `searching` state when no bridge host is running (no error spam)
    - [ ] All Phase 0.5 modules are imported and wired (Protocol, DiscoveryStateMachine, ActionRouter, MessageBuffer)
    - [ ] Heartbeat runs independently from script execution
    - [ ] Edit plugin survives Play/Stop mode transitions

- [ ] **2.2** Execute action handler in plugin (S)
  - File: `templates/studio-bridge-plugin/src/Actions/ExecuteAction.lua`
  - Dependencies: 2.1
  - Agent-assignable: no (Luau in Studio context)
  - Acceptance: handles `requestId` correlation, sends `output`+`scriptComplete`, queues concurrent requests, handles `loadstring` failures

- [ ] **2.3** Health endpoint on bridge host (S)
  - File: `src/bridge/bridge-host.ts` (modify)
  - Dependencies: 1.3d5
  - Agent-assignable: yes
  - Acceptance: `GET /health` returns `{ status, port, protocolVersion, serverVersion, sessions }`, 404 for non-matching paths

- [ ] **2.4** Universal plugin management module + installer commands (M)
  - Files: `src/plugins/plugin-manager.ts`, `plugin-template.ts`, `plugin-discovery.ts`, `types.ts`, `index.ts`, `src/commands/install-plugin.ts`, `src/commands/uninstall-plugin.ts`, `src/commands/index.ts` (add to barrel)
  - Dependencies: 2.1, 1.7b (barrel pattern)
  - Agent-assignable: yes
  - Acceptance: generic `PluginManager` API (works with any `PluginTemplate`), `registerTemplate`, `buildAsync`, `installAsync`, `uninstallAsync`, `isInstalledAsync`, `listInstalledAsync`, hash-based update, generality test with hypothetical second template. Commands registered via `src/commands/index.ts` barrel (NOT by modifying `cli.ts`).

- [ ] **2.5** Persistent plugin detection and fallback (S)
  - Files: `src/bridge/bridge-connection.ts`, `src/plugin/plugin-injector.ts` (modify)
  - Dependencies: 2.3, 2.4
  - Agent-assignable: no (integration edge cases need manual verification)
  - Acceptance: persistent plugin installed -> wait for discovery; not installed -> fallback to temp injection after grace period; `preferPersistentPlugin` option

- [ ] **2.6** Refactor exec/run to handler pattern + session selection + launch command (M)
  - Files: `src/commands/exec.ts`, `src/commands/run.ts`, `src/commands/launch.ts` (create); `src/commands/index.ts` (add to barrel); `src/cli/args/global-args.ts`, `src/cli/cli.ts` (global options only), `src/cli/commands/exec-command.ts`, `src/cli/commands/run-command.ts`, `src/cli/commands/terminal/terminal-mode.ts` (modify)
  - Dependencies: 1.3d5, 1.4, 1.7a, 1.7b (barrel pattern)
  - Agent-assignable: no (UX decisions, interactive testing needed)
  - Acceptance: single-handler pattern, `--session` flag, auto-select single session, error on multiple without flag, fallback to launch on zero, origin tracking, `launch` command. Commands registered via `src/commands/index.ts` barrel (NOT by adding per-command `.command()` calls to `cli.ts`).

### Phase 2 Gate

- [ ] Health endpoint returns correct JSON
- [ ] Full launch flow with mock plugin discovery
- [ ] Plugin fallback to hello on v1 server
- [ ] Plugin reconnection after disconnect
- [ ] `install-plugin` writes to correct path
- [ ] `exec` command session resolution (all three scenarios)
- [ ] `exec` e2e with mock plugin

> Manual Studio testing deferred to Phase 6 (E2E). See `validation/06-integration.md`.

**Phase 2 gate reviewer checklist**:
- [ ] `rojo build templates/studio-bridge-plugin/default.project.json -o dist/studio-bridge-plugin.rbxm` succeeds and output is > 1KB
- [ ] `cd tools/studio-bridge && npm run test` passes with zero failures (all Phase 1 + Phase 2 tests)
- [ ] `studio-bridge install-plugin` writes the `.rbxm` to the correct platform-specific plugins folder
- [ ] `studio-bridge exec 'print("hello")'` with one active session auto-selects it and returns output
- [ ] PluginManager generality test passes: second template registers, builds, and installs without PluginManager code changes

---

## Phase 3: New Action Commands

> Plan: `phases/03-commands.md` | Agent prompts: `agent-prompts/03-commands.md` | Validation: `validation/03-commands.md`
> Depends on Tasks 1.6, 1.7a, 2.1

### Parallelization

```
1.7a (shared CLI utils) --> 3.1 (state) --------+
                        --> 3.2 (screenshot) ----+
                        --> 3.3 (logs) ----------+--> 3.5 (wire terminal adapter)
                        --> 3.4 (query) ---------+
```

### Tasks

- [ ] **3.1** State query action (S)
  - Plugin: `templates/studio-bridge-plugin/src/Actions/StateAction.lua`
  - Server: `src/server/actions/query-state.ts`
  - Command: `src/commands/state.ts`, `src/commands/index.ts` (add to barrel)
  - Dependencies: 1.6, 1.7b (barrel pattern), 2.1
  - Agent-assignable: yes (each layer is simple)
  - Acceptance: single handler in `src/commands/state.ts`, registered via `src/commands/index.ts` barrel (NOT `cli.ts`), prints Place/PlaceId/GameId/Mode, `--json`, `--watch` subscribes to stateChange, 5s timeout

- [ ] **3.2** Screenshot capture action (M)
  - Plugin: `templates/studio-bridge-plugin/src/Actions/ScreenshotAction.lua`
  - Server: `src/server/actions/capture-screenshot.ts`
  - Command: `src/commands/screenshot.ts`, `src/commands/index.ts` (add to barrel)
  - Dependencies: 1.6, 1.7b (barrel pattern), 2.1
  - Agent-assignable: no (requires real Studio testing for CaptureService edge cases)
  - Acceptance: single handler in `src/commands/screenshot.ts`, registered via `src/commands/index.ts` barrel (NOT `cli.ts`), writes PNG, `--output`, `--base64`, `--open`, 15s timeout, error if CaptureService call fails at runtime

- [ ] **3.3** Log query action (M)
  - Plugin: `templates/studio-bridge-plugin/src/Actions/LogAction.lua`
  - Server: `src/server/actions/query-logs.ts`
  - Command: `src/commands/logs.ts`, `src/commands/index.ts` (add to barrel)
  - Dependencies: 1.6, 1.7b (barrel pattern), 2.1
  - Agent-assignable: yes (well-specified)
  - Acceptance: single handler in `src/commands/logs.ts`, registered via `src/commands/index.ts` barrel (NOT `cli.ts`), `--tail`, `--head`, `--follow`, `--level`, `--all`, `--json`, ring buffer (1000 entries)

- [ ] **3.4** DataModel query action (L)
  - Plugin: `templates/studio-bridge-plugin/src/Actions/DataModelAction.lua`, `ValueSerializer.lua`
  - Server: `src/server/actions/query-datamodel.ts`
  - Command: `src/commands/query.ts`, `src/commands/index.ts` (add to barrel)
  - Dependencies: 1.6, 1.7b (barrel pattern), 2.1
  - Agent-assignable: no (complex Roblox type serialization, requires Studio testing)
  - Acceptance: single handler in `src/commands/query.ts`, registered via `src/commands/index.ts` barrel (NOT `cli.ts`), dot-path resolution, `--children`, `--descendants`, `--depth`, `--properties`, `--attributes`, SerializedValue with `type` discriminant and flat `value` arrays, 10s timeout

- [ ] **3.5** Wire terminal adapter registry into terminal-mode.ts (S)
  - Files: `src/commands/connect.ts`, `src/commands/disconnect.ts` (create); `src/cli/commands/terminal/terminal-mode.ts`, `src/cli/commands/terminal/terminal-editor.ts` (modify)
  - Dependencies: 1.7b, 2.6, 3.1, 3.2, 3.3, 3.4
  - Agent-assignable: no (interactive REPL UX, manual testing)
  - Acceptance: `.state`, `.screenshot`, `.logs`, `.query`, `.sessions`, `.connect`, `.disconnect`, `.help` all dispatch through adapter, no handler logic in terminal files

### Phase 3 Gate -- REVIEW CHECKPOINT

- [ ] All four action handler unit tests passing (state, screenshot, logs, query)
- [ ] DataModel path prefixing tests
- [ ] CLI command format tests (state, screenshot)
- [ ] Full lifecycle e2e including all actions
- [ ] Concurrent request tests

> Manual Studio testing deferred to Phase 6 (E2E). See `validation/06-integration.md`.

**Phase 3 gate reviewer checklist**:
- [ ] All four commands (`state`, `screenshot`, `logs`, `query`) are defined once in `src/commands/` and registered via `src/commands/index.ts` barrel (no per-command `cli.ts` modifications)
- [ ] `studio-bridge state --json` returns valid JSON with Place, PlaceId, GameId, Mode, Context fields
- [ ] `studio-bridge logs --follow` subscribes to `logPush` events via WebSocket push protocol and streams output
- [ ] `studio-bridge query Workspace.NonExistent` returns a clear error message (not a stack trace)
- [ ] `cd tools/studio-bridge && npm run test` passes with zero failures (all Phase 1 + 2 + 3 tests)

---

## Phase 4: Split Server Mode

> Plan: `phases/04-split-server.md` | Agent prompts: `agent-prompts/04-split-server.md` | Validation: `validation/04-split-server.md`
> Depends on Task 1.3d5 (bridge module). Can proceed in parallel with Phases 2-3.

### Parallelization

```
4.1 (serve command) ------------------------------------------------+
                                                                     +--> (both done)
4.2 (remote client) --> 4.3 (auto-detection) --> 6.5 (CI integration)|
```

> **Sequential chain**: Tasks 4.2, 4.3, and 6.5 all modify `bridge-connection.ts` and MUST run sequentially (4.2 -> 4.3 -> 6.5) to avoid merge conflicts. Task 6.5 is listed under Phase 6 but is sequenced here because of the shared file dependency.

### Tasks

- [ ] **4.1** Serve command -- thin wrapper (S)
  - File: `src/commands/serve.ts` (create)
  - Dependencies: 1.3d5, 1.7a
  - Agent-assignable: yes
  - Acceptance: binds port 38741, stays alive until killed, `--port`, `--json`, `--log-level`, `--timeout`, SIGTERM/SIGINT trigger graceful shutdown, clear error if port in use

- [ ] **4.2** Remote bridge client (devcontainer CLI) (S)
  - Files: `src/bridge/bridge-connection.ts` (modify), `src/cli/args/global-args.ts` (modify)
  - Dependencies: 1.3d5
  - Agent-assignable: yes
  - Acceptance: `--remote localhost:38741` connects as client, `--local` forces local mode, all commands work through remote, clear error messages

- [ ] **4.3** Devcontainer auto-detection (S)
  - Files: `src/bridge/internal/environment-detection.ts` (create), `src/bridge/bridge-connection.ts` (modify)
  - Dependencies: 4.2
  - Agent-assignable: yes
  - Acceptance: detects `REMOTE_CONTAINERS`/`CODESPACES` env or `/.dockerenv`, auto-connects to remote, falls back to local with warning

### Phase 4 Gate

- [ ] Daemon accepts plugin + CLI relay
- [ ] Daemon survives CLI disconnect
- [ ] Devcontainer auto-detection test
- [ ] Manual verification in devcontainer (see `validation/04-split-server.md`)

---

## Phase 5: MCP Integration

> Plan: `phases/05-mcp-server.md` | Agent prompts: `agent-prompts/05-mcp-server.md` | Validation: `validation/05-mcp-server.md`
> Depends on Phase 3 (all command handlers must exist) and Task 1.7

### Parallelization

```
5.1 (scaffold) --> 5.2 (MCP adapter / tool generation)
               --> 5.3 (transport + config)
```

### Tasks

- [ ] **5.1** MCP server scaffold and `mcp` command (M)
  - Files: `src/mcp/mcp-server.ts`, `src/mcp/index.ts`, `src/commands/mcp.ts` (create); `src/commands/index.ts`, `package.json` (modify)
  - Dependencies: 1.7a, Phase 3 complete
  - Agent-assignable: no (requires integration testing with Claude Code; SDK choice is decided: use `@modelcontextprotocol/sdk`)
  - Acceptance: `studio-bridge mcp` starts MCP server via stdio, connects to bridge, advertises all MCP-eligible tools, `mcp` command itself not exposed as tool, logs to stderr

- [ ] **5.2** MCP adapter (tool generation from CommandDefinitions) (M)
  - File: `src/mcp/adapters/mcp-adapter.ts` (create)
  - Dependencies: 5.1, 1.7a
  - Agent-assignable: yes
  - Acceptance: `createMcpTool` generates from `CommandDefinition`, uses `mcpName`/`mcpDescription`, auto-generated JSON Schema from `ArgSpec`, `interactive: false` session resolution, screenshot returns image content block, no per-tool files

- [ ] **5.3** MCP transport and configuration (S)
  - File: `src/mcp/mcp-server.ts` (modify)
  - Dependencies: 5.1, 5.2
  - Agent-assignable: yes
  - Acceptance: stdio JSON-RPC via `StdioServerTransport`, Claude Code config entry works, `--remote` for devcontainer, `--log-level` controls stderr

### Phase 5 Gate

- [ ] MCP server advertises all six tools
- [ ] `studio_exec` returns structured result
- [ ] `studio_state` returns JSON
- [ ] `studio_screenshot` returns image content block
- [ ] Session auto-selection (single + multiple error)
- [ ] Manual verification with Claude Code (see `validation/05-mcp-server.md`)

---

## Phase 6: Polish & Integration -- REVIEW CHECKPOINT (Release Gate)

> **Hard release gate.** Phase 6 verification (see `validation/06-integration.md`) MUST pass before any public release. A review agent can verify automated test results, code quality, and export correctness. However, items requiring Roblox Studio (E2E plugin testing) require Studio validation -- no agent can run Studio. A release that passes CI but fails the Phase 6 Studio checklist ships a broken product. Treat Phase 6 completion as the release gate, not Phase 5 completion.

> Plan: `phases/06-integration.md` | Agent prompts: `agent-prompts/06-integration.md` | Validation: `validation/06-integration.md`
> Depends on all phases

**Release gate reviewer checklist**:
- [ ] All automated test suites pass (`cd tools/studio-bridge && npm run test`) including e2e tests from Task 6.2
- [ ] Manual Studio E2E validation passes: plugin installs, discovers server, connects, survives Play/Stop transitions (validation/06-integration.md section 4, items 1-9)
- [ ] All six action commands work against a real Studio instance: `exec`, `state`, `screenshot`, `logs`, `query`, `sessions` (validation/06-integration.md section 4, items 10-17)
- [ ] Context-aware commands verified in real Play mode: `--context server` and `--context client` target the correct DataModel (validation/06-integration.md section 4, items 18-23)
- [ ] `index.ts` exports all v1 types unchanged AND all new v2 types (`BridgeConnection`, `BridgeSession`, `SessionInfo`, etc.)

### Tasks

- [ ] **6.1** Update existing tests (M)
  - Files: `src/server/studio-bridge-server.test.ts`, `web-socket-protocol.test.ts` (modify)
  - Dependencies: Phases 1-3
  - Agent-assignable: no (integration tests, understanding of full system needed)

- [ ] **6.2** End-to-end test suite (L)
  - Files: `src/test/e2e/persistent-session.test.ts`, `split-server.test.ts`, `hand-off.test.ts`, `src/test/helpers/mock-plugin-client.ts` (create)
  - Dependencies: Phases 1-4
  - Agent-assignable: no (orchestrating multi-process tests)

- [ ] **6.3** Migration guide (S)
  - Dependencies: all phases
  - Agent-assignable: no (technical writing requiring understanding of user workflows)

- [ ] **6.4** Update index.ts exports (S)
  - File: `src/index.ts` (modify)
  - Dependencies: all phases
  - Agent-assignable: yes

- [ ] **6.5** CI integration (S)
  - File: `src/bridge/bridge-connection.ts` (modify)
  - Dependencies: 4.3 (sequential chain: 4.2 -> 4.3 -> 6.5 -- all modify `bridge-connection.ts`)
  - Agent-assignable: yes
  - Acceptance: `CI=true` -> `preferPersistentPlugin: false`, existing CI workflows pass
  - NOTE: Must run after 4.3 completes. Tasks 4.2, 4.3, and 6.5 all modify `bridge-connection.ts` and must be sequenced to avoid merge conflicts.

---

## Critical Path

The longest dependency chain (11 sequential steps) determines the minimum timeline:

```
1.1 (protocol v2)
  -> 1.5 (v2 handshake)
    -> 1.6 (action dispatch)
      -> 2.1 (persistent plugin core)
        -> 2.2 (execute action in plugin)
          -> 2.5 (detection + fallback)
            -> 3.1-3.4 (new actions, parallel) <- also needs 1.7a
              -> 3.5 (wire terminal adapter)
                -> 5.1 (MCP scaffold)
                  -> 5.2 (MCP tools via adapter)
                    -> 6.2 (e2e tests)
```

### Tasks that block the most downstream work

1. **Task 1.1** (protocol v2) -- blocks everything in Phases 2, 3, and 5
2. **Task 1.3a-d** (bridge module) -- 1.3a blocks 1.3b, 1.3c, and Phase 1b (1.8); 1.3d5 blocks 1.4, 1.7a, 1.7b, Phase 1b (1.9, 1.10), all of Phase 4, 2.3, 2.6. Split into sub-tasks: 1.3a (transport + host) -> 1.3b (sessions) + 1.3c (client) in parallel -> 1.3d1 -> 1.3d2 -> 1.3d3 -> 1.3d4 (all agent-assignable) -> 1.3d5 (review checkpoint, ~30 min).
3. **Task 1.7a** (shared CLI utilities) -- blocks all command implementations in Phases 2-3 (2.6, 3.1-3.4) and the MCP adapter (5.2). Sessions command (1.7b) serves as the reference implementation.
4. **Task 1.6** (action dispatch) -- blocks all action implementations in Phase 3
5. **Task 2.1** (persistent plugin core) -- blocks all plugin-side action handlers

### Off the critical path but important

- **Phase 0** (output modes) -- independent, can be done any time before 1.7a. Task 1.7a integrates them.
- **Phase 0.5** (plugin modules) -- runs in parallel with Phase 0 and Phase 1. Only becomes blocking if 0.5.4 (Lune integration tests) is slow. Early completion de-risks Phase 2 plugin work.
- **Phase 1b** (failover: 1.8, 1.9, 1.10) -- runs in parallel with Phases 2-3. No longer blocks downstream work. 1.8 depends on 1.3a (can start early); 1.9 and 1.10 depend on 1.3d5 and 1.8.
- **Sessions command** (1.7b) -- moved earlier into Phase 1, immediately after shared CLI utilities (1.7a). Validates the CLI utility layer before Phase 2 begins.
- **Phase 4** (split server) -- depends only on 1.3d5 and 1.7a, can run in parallel with Phases 2-3.
- **CommandDefinition extraction** -- deferred to Phase 5 (MCP adapter). Phase 3 commands use shared CLI utilities directly.

### Priority start order

Tasks 1.1, 1.3a, 0.1-0.4, and 0.5.1 should be prioritized above all others and can all proceed in parallel. Tasks 1.3b and 1.3c should start as soon as 1.3a is complete. Task 1.8 (failover) can also start once 1.3a is done but no longer blocks other work. Subtasks 1.3d1-1.3d4 should start as soon as 1.3b and 1.3c are complete (these are agent-assignable and run in sequence). Task 1.7a should start as soon as 1.3d5 and 0.4 are complete.

---

## Delegation Quick Reference

### Agent-assignable tasks by phase

| Phase | Tasks | Agent prompt file |
|-------|-------|-------------------|
| 0 | 0.1, 0.2, 0.3, 0.4 | `agent-prompts/00-prerequisites.md` |
| 0.5 | 0.5.1, 0.5.2, 0.5.3, 0.5.4 | `agent-prompts/02-plugin.md` |
| 1 | 1.1, 1.2, 1.3a, 1.3b, 1.3c, 1.3d1, 1.3d2, 1.3d3, 1.3d4, 1.4, 1.5, 1.6, 1.7a, 1.7b | `agent-prompts/01-bridge-network.md` |
| 1b | 1.10 | `agent-prompts/01-bridge-network.md` |
| 2 | 2.3, 2.4 | `agent-prompts/02-plugin.md` |
| 3 | 3.1, 3.3 | `agent-prompts/03-commands.md` |
| 4 | 4.1, 4.2, 4.3 | `agent-prompts/04-split-server.md` |
| 5 | 5.2, 5.3 | `agent-prompts/05-mcp-server.md` |
| 6 | 6.4, 6.5 | `agent-prompts/06-integration.md` |

### Requires review agent or orchestrator coordination

| Task | Reason | Review approach |
|------|--------|----------------|
| 1.3d5 (barrel export + API surface review) | API surface must match tech spec contract. Subtasks 1.3d1-1.3d4 are agent-assignable. | Review agent verifies exports against `07-bridge-network.md` section 2.1 |
| 1.8 (failover impl) | Multi-process coordination, timing races, real sockets. Now in Phase 1b, no longer blocks other phases | Skilled agent implements; review agent verifies state machine correctness and test coverage |
| 1.9 (failover tests) | Integration tests with concurrent processes, port races, timing. Now in Phase 1b | Skilled agent implements; review agent verifies timing assertions and cleanup |
| 2.1 (persistent plugin) | Complex Luau with Roblox service wiring. Requires Studio validation for runtime behavior | Agent implements code + Lune tests; Studio validation deferred to Phase 6 |
| 2.2 (execute action) | Luau in Studio context | Agent implements; review agent checks code quality and test coverage |
| 2.5 (detection + fallback) | Integration edge cases between plugin detection and fallback | Agent implements with thorough tests; review agent verifies edge case coverage |
| 2.6 (exec/run refactor) | Session resolution UX, handler pattern migration | Agent implements; review agent verifies pattern consistency and test coverage |
| 3.2 (screenshot) | CaptureService confirmed working; requires Studio validation for edge cases | Agent implements code + mock tests; Studio validation deferred to Phase 6 |
| 3.4 (DataModel query) | Complex Roblox type serialization, requires Studio validation | Agent implements code + mock tests; Studio validation deferred to Phase 6 |
| 3.5 (terminal adapter) | Interactive REPL wiring to adapter registry | Agent implements; review agent verifies dispatch pattern and dot-command coverage |
| 5.1 (MCP scaffold) | MCP SDK integration; needs Claude Code validation | Agent implements; Claude Code validation is a separate step |
| 6.1, 6.2, 6.3 (polish) | Full-system understanding needed for test updates and migration guide | Agent implements with full codebase context; review agent verifies completeness |

### Recommended parallelization groups

These groups of tasks can be delegated simultaneously:

**Wave 1** (no dependencies):
- 0.1, 0.2, 0.3 (output modes -- different package)
- 0.5.1 (protocol module -- Luau, independent)
- 1.1 (protocol v2)
- 1.2 (pending request map)
- 1.3a (transport + host) -- start early, first step of bridge module

**Wave 2** (after 1.1 and/or 1.3a complete):
- 0.4 (barrel -- after 0.1-0.3)
- 0.5.2 (discovery state machine -- after 0.5.1)
- 0.5.3 (action router + message buffer -- after 0.5.1)
- 1.3b (sessions -- after 1.3a)
- 1.3c (client -- after 1.3a)
- 1.5 (v2 handshake -- after 1.1)
- 1.8 (failover impl -- after 1.3a; Phase 1b, non-blocking)

**Wave 3** (after Wave 2):
- 0.5.4 (Lune integration tests -- after 0.5.1-0.5.3, 1.3a)
- **1.3d1-1.3d4 (BridgeConnection subtasks -- after 1.3a, 1.3b, 1.3c) -- Agent-assignable, run in sequence: 1.3d1 -> 1.3d2 -> 1.3d3 -> 1.3d4. These can proceed without human intervention.**
- 1.6 (action dispatch -- after 1.1, 1.2, 1.5)
- 1.9 (failover tests -- after 1.3d5, 1.8; Phase 1b, non-blocking)
- 2.1 (persistent plugin -- after 1.1)

**Wave 3.5** (after 1.3d4 complete -- review checkpoint on 1.3d5 only):
- **1.3d5 (barrel export + API review) -- REVIEW CHECKPOINT: ~30-minute review task. The orchestrator dispatches this to a review agent (or performs the checklist verification itself) after 1.3d1-1.3d4 are complete. Do NOT dispatch Wave 3.5+ tasks (1.4, 1.7a, etc.) until 1.3d5 is validated and merged.**
- 1.4 (StudioBridge wrapper -- after 1.3d5)
- 1.7a (shared CLI utilities -- after 1.3d5, 0.4)
- 1.10 (failover observability -- after 1.3d5, 1.8; Phase 1b, non-blocking)
- 2.3 (health endpoint -- after 1.3d5)

**Wave 4** (after 1.7a complete -- Phase 1 gate no longer requires failover):
- 1.7b (sessions command -- after 1.7a)
- 2.2 (execute action -- after 2.1)
- 2.4 (plugin manager -- after 2.1)
- 2.6 (exec/run refactor -- after 1.3d5, 1.4, 1.7a)
- 4.1 (serve command -- after 1.3d5, 1.7a)
- 4.2 (remote client -- after 1.3d5) -- **starts the bridge-connection.ts sequential chain: 4.2 -> 4.3 -> 6.5**

**Wave 5** (after Phase 2 core):
- 2.5 (detection + fallback -- after 2.3, 2.4)
- 3.1, 3.2, 3.3, 3.4 (all actions -- after 1.6, 1.7a, 2.1)
- 4.3 (auto-detection -- after 4.2) -- **sequential: must complete before 6.5 starts (bridge-connection.ts chain)**
- 6.5 (CI integration -- after 4.3) -- **sequential: last in bridge-connection.ts chain (4.2 -> 4.3 -> 6.5)**

**Wave 6** (after Phase 3):
- 3.5 (terminal wiring -- after 3.1-3.4, 1.7b, 2.6)
- 5.1 (MCP scaffold -- after Phase 3, 1.7a)

**Wave 7** (after MCP scaffold):
- 5.2, 5.3 (MCP adapter + transport -- after 5.1)

**Wave 8** (final):
- 6.1, 6.2, 6.3, 6.4 (polish -- after all phases)

### Two-agent execution model (required)

> **Cap parallelism at 2 agents.** The wave table above shows theoretical parallelism of up to 7 concurrent tasks. In practice, merge overhead and conflict risk exceed the parallelism gain above 2 agents. The execution model is exactly 2 agents with file-ownership boundaries that eliminate merge conflicts entirely. Do NOT attempt to run more than 2 concurrent sub-agents.

**Agent A** (TypeScript infrastructure):
- **Owns**: `src/bridge/`, `src/server/`, `src/mcp/`, `tools/cli-output-helpers/`
- Phase 0 (output modes in `tools/cli-output-helpers/`)
- Phase 1 core (protocol, bridge host/client, session tracker, shared utils)
- Phase 2: health endpoint only (2.3)
- Phase 4 (serve command, remote client, devcontainer)
- Phase 5 (MCP integration)

Sequence: `0.1-0.4` -> `1.1` -> `1.2` -> `1.3a` -> `1.3b` + `1.3c` (parallel) -> `1.3d1-1.3d5` -> `1.5` -> `1.6` -> `2.3` -> `3.1` -> `3.3` -> `4.1` -> `4.2` -> `4.3` -> `5.1` -> `5.2` -> `5.3`

**Agent B** (Luau plugin + CLI commands):
- **Owns**: `templates/`, `src/commands/`, `src/cli/`, `src/plugins/`
- Phase 0.5 (Lune-testable plugin modules)
- Phase 1b (failover, parallel with Agent A's Phase 2-3 work)
- Phase 2 (plugin wiring, plugin manager, CLI refactor)
- Phase 3 (action commands + terminal wiring)
- Phase 6 (polish, tests, migration)

Sequence: `0.5.1-0.5.3` -> `0.5.4` (after A: 1.3a) -> `1.4` (after A: 1.3d5) -> `1.7a` (after A: 0.4, 1.3d5) -> `1.7b` -> `1.8` (after A: 1.3a) -> `1.9` (after A: 1.3d5) -> `1.10` -> `2.1` -> `2.2` -> `2.4` -> `2.5` -> `2.6` -> `3.2` -> `3.4` -> `3.5` -> `6.1` -> `6.2`

**Zero file overlap between agents.** Merges are always clean -- just combine branches.

### Realistic parallelism per wave

The wave table above shows theoretical max parallelism. The table below shows what is realistic with the 2-agent model:

| Wave | Theoretical Parallelism | Realistic (2 agents) | Why |
|------|------------------------|---------------------|-----|
| 1 | 7 | **2** | Agent A: 0.1-0.3, 1.1, 1.2, 1.3a. Agent B: 0.5.1. All new files, clean merges. |
| 2 | 7 | **2** | Agent A: 0.4, 1.3b, 1.3c, 1.5. Agent B: 0.5.2, 0.5.3, 1.8. Mostly new files. |
| 3 | 5 | **2** | Agent A: 1.3d1-1.3d4 (agent-assignable), 1.6. Agent B: 0.5.4, 2.1. 1.3d5 is a review checkpoint (~30 min). |
| 3.5 | 4 | **2** | Agent A: 2.3. Agent B: 1.4, 1.7a, 1.10. Gated on 1.3d5. |
| 4 | 7 | **2** | Agent A: 4.1, 4.2. Agent B: 1.7b, 2.2, 2.4, 2.6. cli.ts conflicts serialize to B. |
| 5 | 6 | **2** | Agent A: 4.3. Agent B: 2.5, 3.1-3.4. Action commands serialize within B. |
| 6 | 2 | **2** | Agent A: 5.1. Agent B: 3.5. Natural funnel. |
| 7 | 2 | **2** | Agent A: 5.2, 5.3. Agent B: idle or starting 6.x. |
| 8 | 4 | **2** | Agent A: idle. Agent B: 6.1-6.4. Integration needs merged context. |

### Sync points

There are 6 sync points where Agent A's output unblocks Agent B. At each sync point, the orchestrator merges Agent A and Agent B branches and runs post-merge validation before Agent B proceeds.

| # | Sync Point | Agent A has completed | Agent B is unblocked to start | Post-merge validation |
|---|-----------|----------------------|-------------------------------|----------------------|
| SP-1 | After 1.1 (protocol types) | 1.1 (v2 type definitions) | B can use protocol types in plugin modules (2.1) | `cd tools/studio-bridge && npm run test` |
| SP-2 | After 1.3a (transport) | 1.3a (transport + bridge host) | B can start 0.5.4 (Lune integration tests) and 1.8 (failover) | `cd tools/studio-bridge && npm run test` |
| SP-3 | After 1.3d5 (BridgeConnection) | 1.3d1-1.3d5 (BridgeConnection subtasks) | B can start 1.4 (StudioBridge wrapper), 1.7a (shared CLI utils), 1.9 (failover tests), 1.10 (observability), 2.3 (health, assigned to A but unblocks B's plugin discovery) | `cd tools/studio-bridge && npm run test` |
| SP-4 | After 1.7a + 1.7b (shared utils + reference command) | 1.7a (shared CLI utilities), 1.7b (sessions command) | B can start 3.1-3.4 (action commands), 2.6 (exec/run refactor) | `cd tools/studio-bridge && npm run test` |
| SP-5 | After 2.3 (health endpoint) | 2.3 (health endpoint on bridge host) | B can integrate plugin discovery (2.5) | `cd tools/studio-bridge && npm run test` |
| SP-6 | After Phase 4 complete | 4.1 (serve), 4.2 (remote client), 4.3 (auto-detection) | B can add devcontainer-aware behavior to CLI commands | `cd tools/studio-bridge && npm run test` |

**Orchestrator workflow at each sync point:**
1. Wait for Agent A to complete the specified tasks
2. Wait for Agent B to complete its current in-progress work (do NOT interrupt mid-task)
3. Merge Agent A's branch into Agent B's branch (or both into a shared integration branch)
4. Run the post-merge validation command
5. If validation fails, create a remediation task before Agent B proceeds
6. If validation passes, dispatch Agent B's next tasks

### Post-merge validation

After merging Agent A and Agent B branches at each sync point, the orchestrator MUST run validation on the merged result. This catches "works in isolation, fails combined" issues early.

**Validation command at every sync point:**

```bash
cd /workspaces/NevermoreEngine/tools/studio-bridge && npm run test
```

**What to do when post-merge validation fails:**
1. Identify which test(s) failed and which agent's code is involved
2. If the failure is in Agent A's code: assign a fix task to Agent A before dispatching Agent B's next work
3. If the failure is in Agent B's code: assign a fix task to Agent B
4. If the failure is an integration issue (both agents' code interacts incorrectly): the orchestrator creates a targeted remediation task describing the conflict, assigns it to whichever agent owns the failing file, and provides the other agent's code as read-only context
5. Re-run validation after the fix. Do NOT proceed past the sync point until validation passes.

**Why this matters:** Each sync point is where Agent B first consumes Agent A's types, APIs, or runtime behavior. Type mismatches, import path errors, and behavioral assumptions are most likely to surface here. Catching them immediately (rather than at Phase 6 E2E) saves significant rework.

---

## Known Risks

| # | Risk | Mitigation | Contingency |
|---|------|-----------|-------------|
| 1 | **CaptureService runtime failures** -- confirmed working in Studio plugins, but may fail at runtime when minimized or under resource constraints | Wrap in `pcall`, return clear `SCREENSHOT_FAILED` error with details; always advertise `captureScreenshot` capability | Runtime failures return actionable error messages; all other features independent |
| 2 | **WebSocket reliability in Studio** -- silent drops, truncated frames, missing API | Aggressive reconnection + backoff (2.1), heartbeats every 15s, generous frame limits (16MB), base64 for binary data | Fall back to temporary plugin for shorter sessions |
| 3 | **Cross-platform plugin paths** -- macOS vs Windows vs Linux (wine) | `findPluginsFolder()` already handles macOS/Windows; verify in 2.4; print exact path; fail with manual install instructions | Manual install instructions |
| 4 | **Port forwarding in devcontainers** -- 38741 may not auto-forward | Document requirement; recommend `forwardPorts` in devcontainer.json; auto-detection fallback; `--remote` override | `--remote` flag bypasses auto-detection |
| 5 | **Port contention on 38741** -- another process may use the port | `EADDRINUSE` = connect as client; `--port` override; clear error messages | `--port` flag for alternate port |
| 6 | **Orphaned plugins after host crash** -- no clients to take over | Exponential backoff polling (max 30s); next CLI becomes host; hand-off protocol (Phase 1b: 1.8); `SO_REUSEADDR` (1.8); idle grace period (5s) | Plugins reconnect on next CLI invocation |
| 7 | **Failover timing races** -- duplicate hosts, lost sessions, silent failures | Hardened state machine (Phase 1b: 1.8), dedicated test suite (1.9), structured logging (1.10), random jitter (0-500ms), immediate `SessionDisconnectedError`, health endpoint diagnostics | Fall back to non-transferable hosts (restart from scratch on host death) |

---

## Merge Conflict Mitigation

Two file hotspots have been identified and mitigated:

### `cli.ts` -- barrel export pattern (7 tasks)

**Problem**: Tasks 1.7b, 2.4, 2.6, 3.1, 3.2, 3.3, 3.4 all need to register CLI commands. If each task modifies `cli.ts` directly to add `.command()` calls, parallel execution produces merge conflicts at the same lines.

**Solution**: Barrel export pattern. Task 1.7b establishes it:
1. `src/commands/index.ts` (barrel file) exports all command handlers and an `allCommands` array.
2. `src/cli/cli.ts` imports `allCommands` and registers them in a single loop: `for (const cmd of allCommands) { cli.command(createCliCommand(cmd)); }`.
3. Each subsequent task creates its command handler file in `src/commands/` AND adds an export line to the barrel file. The barrel file is append-only, so concurrent additions auto-merge cleanly.
4. `cli.ts` is NEVER modified again for command registration after Task 1.7b.

**Impact**: All 7 tasks can run in parallel worktrees without conflict. Each task modifies only its own handler file and appends to the barrel file.

### `bridge-connection.ts` -- sequential chain (3 tasks)

**Problem**: Tasks 4.2, 4.3, and 6.5 all modify `src/bridge/bridge-connection.ts`. They touch different sections of the class, but auto-merge is not guaranteed.

**Solution**: Sequence these tasks: 4.2 -> 4.3 -> 6.5. The time saved by parallelizing three small tasks does not justify the merge risk. Task 6.5 is listed under Phase 6 but executes immediately after 4.3 in the wave schedule.

---

## Notes

- This document mirrors the structure of the execution plan in `phases/` but is designed for operational tracking
- For detailed task specifications, always refer to the corresponding phase file
- For detailed test specifications, refer to the corresponding validation file
- For agent delegation, use the self-contained prompts in `agent-prompts/`
- The output-modes-plan.md contains the detailed design for Phase 0 including API signatures
