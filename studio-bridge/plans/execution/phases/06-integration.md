# Phase 6: Polish

Goal: Documentation, migration guide, end-to-end testing, and cleanup.

References:
- Overview: `studio-bridge/plans/tech-specs/00-overview.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/06-integration.md`
- Validation: `studio-bridge/plans/execution/validation/06-integration.md`

---

### Task 6.1: Update existing tests

**Description**: Ensure all existing tests pass with the refactored code. Add integration tests that exercise the full lifecycle with both temporary and persistent plugin modes.

**Files to modify**:
- `src/server/studio-bridge-server.test.ts` -- add tests for v2 handshake, registry integration, persistent plugin detection.
- `src/server/web-socket-protocol.test.ts` -- already updated in Task 1.1, but verify coverage.

**Dependencies**: All of Phases 1-3.

**Complexity**: M

### Task 6.2: End-to-end test suite

**Description**: Create a test harness that simulates a complete persistent session workflow: install plugin, start server, simulate plugin connection (mock WebSocket client), execute script, query state, capture screenshot (mock), query DataModel (mock), stream logs, disconnect, reconnect.

**Files to create**:
- `src/test/e2e/persistent-session.test.ts` -- full lifecycle test.
- `src/test/e2e/split-server.test.ts` -- bridge host + remote client relay test.
- `src/test/e2e/hand-off.test.ts` -- bridge host transfer and crash recovery test (complements the focused failover tests from Task 1.9 with full-stack e2e scenarios including real commands and session management).
- `src/test/helpers/mock-plugin-client.ts` -- simulates a v2 plugin for testing.

**Dependencies**: All of Phases 1-4.

**Complexity**: L

### Task 6.3: Migration guide

**Description**: Write user-facing documentation covering: how to install the persistent plugin, how to use new commands, how to set up split-server mode for devcontainers, how to configure MCP for AI agents.

**Files to create**:
- Documentation content for the migration guide (exact location determined by docs structure).

**Dependencies**: All phases complete.

**Complexity**: S

### Task 6.4: Update index.ts exports

**Description**: Ensure all new public types and classes are exported from `src/index.ts` for library consumers.

**Files to modify**:
- `src/index.ts` -- export `BridgeConnection`, `BridgeSession`, `BridgeConnectionOptions`, `SessionInfo`, action types, new protocol types, MCP types.

**Dependencies**: All phases complete.

**Complexity**: S

### Task 6.5: CI integration

**Description**: Ensure the bridge host pattern works in CI environments. In CI, the persistent plugin is never installed, so the system must fall back to temporary injection. The bridge host pattern has no disk state, so no temp directory override is needed.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- respect `CI=true` to set `preferPersistentPlugin: false` by default.

**Dependencies**: Task 4.3 (sequential chain: 4.2 -> 4.3 -> 6.5). All three tasks modify `bridge-connection.ts` and MUST be sequenced to avoid merge conflicts. Do NOT start 6.5 until 4.3 is complete and merged.

**Complexity**: S

**Acceptance criteria**:
- In CI (`CI=true` env var), `BridgeConnection` defaults to `preferPersistentPlugin: false`, forcing temporary injection fallback.
- Persistent plugin detection returns `false` in CI.
- All existing CI workflows pass without modification.

---

## Phase 6 Release Gate -- REVIEW CHECKPOINT

> This is the final review checkpoint before any public release. All automated tests must pass AND all items on this checklist must be verified. A review agent can verify code quality, test results, and export correctness. Items requiring Roblox Studio (manual E2E) require Studio validation -- no agent can run Studio.

**Release gate reviewer checklist**:
- [ ] All automated test suites pass (`cd tools/studio-bridge && npm run test`) including e2e tests from Task 6.2
- [ ] Manual Studio E2E validation passes: plugin installs, discovers server, connects, survives Play/Stop transitions (items 1-9 from `validation/06-integration.md` section 4)
- [ ] All six action commands work against a real Studio instance: `exec`, `state`, `screenshot`, `logs`, `query`, `sessions` (items 10-17 from `validation/06-integration.md` section 4)
- [ ] Context-aware commands verified in real Play mode: `--context server` and `--context client` target the correct DataModel (items 18-23 from `validation/06-integration.md` section 4)
- [ ] `index.ts` exports all v1 types unchanged AND all new v2 types (`BridgeConnection`, `BridgeSession`, `SessionInfo`, etc.) -- verified by import assertion tests in Task 6.4

---

## Critical Path

The longest dependency chain determines the minimum number of sequential steps to reach a fully functional system:

```
1.1 (protocol v2)
  -> 1.5 (v2 handshake)
    -> 1.6 (action dispatch)
      -> 2.1 (persistent plugin core)
        -> 2.2 (execute action in plugin)
          -> 2.5 (detection + fallback)
            -> 3.1-3.4 (new actions, parallel) <- also needs 1.7
              -> 3.5 (wire terminal adapter)
                -> 5.1 (MCP scaffold)
                  -> 5.2 (MCP tools via adapter)
                    -> 6.2 (e2e tests)
```

The command handler infrastructure (1.7) feeds into the critical path at 3.1-3.4 but is not on the critical path itself, because it depends only on 1.3 and can be completed well before 1.6 -> 2.1 -> 2.2 -> 2.5 finishes. However, if 1.7 is delayed past 2.5, it becomes a bottleneck for all Phase 3 work.

**Failover tasks (1.8, 1.9, 1.10) are NOT on the critical path** but are a hard Phase 1 gate. They depend only on 1.3 and can proceed in parallel with 1.4-1.7. However, they MUST complete before Phase 2 begins. Commands built in Phases 2-3 assume the bridge network recovers from host death. If failover is broken, every downstream command will have intermittent failures that are extremely hard to diagnose because the symptoms (silent timeouts, missing sessions, duplicate hosts) look like bugs in the command layer, not the networking layer.

**Phase 0 (output modes) is NOT on the critical path.** Tasks 0.1-0.4 modify `tools/cli-output-helpers/`, not `tools/studio-bridge/`, and can be completed at any time before Phase 2. Task 1.7 (command handler infrastructure) is where the output modes are integrated into the CLI adapter. Commands can also use `formatTable` directly in their handler's `summary` composition without the CLI adapter integration, so Phase 0 does not strictly gate Phase 2 work.

**Critical path length**: 12 sequential steps (unchanged -- Phase 0 and failover tasks run in parallel with the critical path).

**Tasks that block the most downstream work**:
1. **Task 1.1 (protocol v2)** -- blocks everything in Phases 2, 3, and 5.
2. **Task 1.3 (bridge module)** -- blocks Task 1.4 (StudioBridge wrapper), Task 1.7 (command handler infra), Tasks 1.8-1.10 (failover), all of Phase 4 (split server), Task 2.3 (health endpoint), Task 2.6 (sessions command), and Task 2.7 (exec/run refactor + session selection). This is the largest foundation task.
3. **Task 1.7 (command handler infra)** -- blocks all command implementations in Phases 2-3 (2.6, 2.7, 3.1-3.4) and the MCP adapter (5.2). Must be completed before any action command task starts. Start immediately after 1.3. Integrates the output mode utilities from Phase 0 into the CLI adapter.
4. **Task 1.6 (action dispatch)** -- blocks all action implementations in Phase 3.
5. **Task 2.1 (persistent plugin core)** -- blocks all plugin-side action handlers.
6. **Task 1.8 (failover implementation)** -- gates Phase 2. If failover is deferred, all commands built on the bridge network will have undiagnosed intermittent failures when hosts restart.

Tasks 1.1, 1.3, and 0.1-0.4 should be prioritized above all others and can all proceed in parallel. Task 1.7 should start as soon as 1.3 is complete -- it is a prerequisite for all command work in Phases 2-3. Tasks 1.8-1.10 should start as soon as 1.3 is complete and must finish before any Phase 2 work begins.

---

## Risk Mitigation

### Risk 1: Roblox CaptureService runtime failures

**Threat**: The screenshot call chain (`CaptureService:CaptureScreenshot` -> `EditableImage` -> pixel read -> base64 encode) is confirmed to work in Studio plugins, but individual steps may fail at runtime in certain conditions (e.g., Studio is minimized, rendering errors, resource constraints, or `EditableImage` API unavailability).

**Mitigation**:
- Each step in the call chain is wrapped in `pcall`: the `CaptureScreenshot` call, `EditableImage` creation via `AssetService:CreateEditableImageAsync`, and pixel read via `ReadPixels` (or similar). Each failure returns a clear `SCREENSHOT_FAILED` error with details about which step failed.
- The `captureScreenshot` capability is always advertised (CaptureService is available in plugin context).
- If a capture fails at runtime, the error message describes the specific failure so the user can take action (e.g., un-minimize Studio).

**Contingency**: Runtime capture failures return actionable error messages. All other features are independent of screenshots.

### Risk 2: WebSocket reliability in Studio

**Threat**: Roblox's `HttpService:CreateWebStreamClient` has been unreliable in some Studio builds -- connections drop silently, large frames are truncated, or the API is missing entirely.

**Mitigation**:
- The persistent plugin implements aggressive reconnection with exponential backoff (Task 2.1).
- Heartbeat messages (every 15 seconds) detect stale connections quickly.
- The server configures generous frame size limits (16MB) and enables per-message compression.
- Large payloads (screenshots) are base64-encoded to avoid binary frame issues.
- If WebSocket creation fails, the plugin logs a clear error and retries after 5 seconds.

**Contingency**: If WebSocket issues are systemic in a particular Studio build, users can fall back to the temporary plugin (which uses the same WebSocket API but for shorter durations).

### Risk 3: Cross-platform plugin path differences

**Threat**: The Studio plugins folder is in different locations on macOS (`~/Library/Application Support/Roblox/Plugins/`) vs Windows (`%LOCALAPPDATA%/Roblox/Plugins/`). Linux (wine) may have yet another path.

**Mitigation**:
- `findPluginsFolder()` in `studio-process-manager.ts` already handles macOS and Windows. Verify it works for all currently supported platforms during Task 2.4.
- The `install-plugin` command prints the exact path it writes to, so users can verify.
- If the plugins folder cannot be detected, the command fails with instructions for manual installation.

### Risk 4: Port forwarding in devcontainers

**Threat**: Split-server mode requires the bridge host port to be forwarded from the host into the devcontainer. VS Code's devcontainer port forwarding is automatic for detected ports, but the bridge host port (38741) may not be auto-detected.

**Mitigation**:
- Document the port forwarding requirement explicitly in the devcontainer setup guide (Task 6.3).
- Recommend adding the port to `.devcontainer/devcontainer.json`'s `forwardPorts` array.
- The auto-detection logic (Task 4.3) tries the port and falls back gracefully with a clear error message.
- The `--remote` flag allows users to specify an arbitrary host:port, bypassing auto-detection.

### Risk 5: Port contention on 38741

**Threat**: The well-known port 38741 may already be in use by another process on the developer's machine, preventing the bridge host from starting.

**Mitigation**:
- `BridgeConnection.connectAsync()` detects `EADDRINUSE` and attempts to connect as a client. If the existing process on that port is not a bridge host (e.g., different application), the connection will fail with a clear error.
- The `--port` flag on `studio-bridge serve` allows using an alternate port.
- If another studio-bridge host is already running, that is the correct behavior -- the new CLI becomes a client.
- Document the port in README so users can avoid conflicts.

### Risk 6: Bridge host crash leaves orphaned plugins

**Threat**: If the bridge host crashes and no clients are connected to take over, plugins enter a polling loop until the next CLI invocation starts a new host.

**Mitigation**:
- Plugins use exponential backoff (1s, 2s, 4s, 8s, max 30s) when polling, so they do not spam the port.
- The next CLI invocation automatically becomes the new host and plugins reconnect within ~2 seconds.
- The hand-off protocol (Tasks 1.3 and 1.8) ensures that if clients ARE connected, one of them takes over immediately.
- The 5-second idle grace period on the host prevents premature exit between rapid CLI invocations.
- `SO_REUSEADDR` on the server socket (Task 1.8) prevents TIME_WAIT from blocking rapid port rebind.
- Structured debug logging (Task 1.10) makes failover issues diagnosable.

### Risk 7: Failover timing races and debugging difficulty

**Threat**: The bridge host is the single point of failure. When it dies, multiple processes (clients, plugins) must coordinate to recover. Timing races during failover can cause duplicate hosts, lost sessions, or silent request failures. Debugging failover issues is extremely difficult because symptoms (silent timeouts, missing sessions) look like application-layer bugs.

**Mitigation**:
- Dedicated failover implementation task (Task 1.8) with hardened state machine and deterministic transitions.
- Dedicated failover integration test suite (Task 1.9) with timing assertions and multi-client scenarios.
- Structured debug logging for every state transition during failover (Task 1.10).
- Random jitter (0-500ms) prevents thundering herd when multiple clients race to become host.
- Inflight requests are rejected with `SessionDisconnectedError` immediately on host death (not left to timeout silently).
- The `health` endpoint includes `lastFailoverAt` timestamp for post-mortem diagnostics.
- The `sessions` command detects failover-in-progress and prints actionable guidance instead of a confusing error.

**Contingency**: If failover proves too complex for the initial release, the fallback is to make hosts non-transferable: when the host dies, clients simply reconnect from scratch. This is worse for UX but eliminates timing races entirely. The test suite (Task 1.9) will reveal whether the full hand-off protocol is stable enough for production.

---

## Testing Strategy (Phase 6)

**End-to-end**:
- Full test suite exercising every feature in both single-process and split-server modes.
- CI pipeline passes with no persistent plugin installed.
- Verify migration guide instructions work on a fresh setup.

---

## Sub-Agent Assignment

### Suitable for sub-agent execution

These tasks are self-contained, have clear inputs/outputs, and do not require human judgment or manual testing with Roblox Studio:

| Task | Rationale |
|------|-----------|
| 0.1-0.4 (output modes) | Pure utility modules in cli-output-helpers. Well-specified in output-modes-plan.md. No studio-bridge dependencies. |
| 1.1 (protocol v2 types) | Pure TypeScript type definitions and decode logic. Well-specified in `01-protocol.md`. |
| 1.2 (pending request map) | Small standalone utility with clear interface. |
| 1.4 (StudioBridge wrapper) | Small modification to existing class, wrapping BridgeConnection. |
| 1.5 (v2 handshake) | Modification to existing handshake handler. Protocol spec is precise. |
| 1.6 (action dispatch) | Standalone dispatch layer. Depends on 1.1 and 1.2 which provide precise types. |
| 2.3 (health endpoint) | Small addition to bridge-host.ts HTTP handler. |
| 2.4 (plugin manager + install commands) | Universal PluginManager API with well-specified interface from `03-persistent-plugin.md` section 2. Pure TypeScript utility with clear types. |
| 1.7 (command handler infra) | Well-specified interfaces and adapters. Spec is precise in `02-command-system.md`. Integrates output modes from Phase 0. |
| 2.6 (sessions command) | Single handler file calling `BridgeConnection.listSessionsAsync()`. |
| 3.1 (state query) | End-to-end but each layer is simple. Single handler in `src/commands/state.ts`. |
| 3.3 (log query) | Moderate complexity, well-specified. |
| 4.1 (serve command) | Thin wrapper around `BridgeConnection.connectAsync({ keepAlive: true })`. |
| 4.2 (remote client) | Small addition to `BridgeConnectionOptions` for remote host. |
| 1.10 (failover observability) | Structured logging additions and health endpoint fields. Small, well-scoped modifications to existing files. |
| 4.3 (devcontainer detection) | Small environment-detection utility. |
| 5.2 (MCP adapter) | Generic adapter from CommandDefinition to MCP tool. Well-specified in `06-mcp-server.md` section 4 and `02-command-system.md` section 10. |
| 5.3 (MCP transport) | Standard MCP SDK integration. Configuration documented in `06-mcp-server.md` section 8. |
| 6.4 (index.ts exports) | Trivial. |
| 6.5 (CI integration) | Small environment-aware changes. |

### Requires review agent, orchestrator coordination, or Studio validation

| Task | Rationale | Review approach |
|------|-----------|----------------|
| 1.3 (bridge module) | Core networking module with host/client detection, hand-off protocol. | Skilled agent implements; review agent verifies design against tech spec and test coverage. |
| 1.8 (failover impl) | Multi-process coordination with timing races. State machine must be deterministic. | Skilled agent implements with real socket tests; review agent verifies state machine correctness. |
| 1.9 (failover tests) | Integration tests involving multiple concurrent processes, port binding races, and timing assertions. | Skilled agent implements; review agent verifies timing assertions and teardown patterns. |
| 2.1 (persistent plugin core) | Complex Luau code with Roblox service wiring. | Agent implements code + Lune tests; Studio validation deferred to Phase 6 E2E. |
| 2.2 (execute action in plugin) | Luau in Studio context, must test with real execute flow. | Agent implements; review agent checks code quality. Requires Studio validation. |
| 2.5 (detection + fallback) | Integration between persistent plugin detection and fallback to temporary injection. | Agent implements with thorough tests; review agent verifies edge case coverage. |
| 2.7 (session selection) | Session resolution UX, handler pattern consistency. | Agent implements; review agent verifies pattern consistency and test coverage. |
| 3.2 (screenshot) | CaptureService confirmed working; runtime edge cases need Studio validation. | Agent implements code + mock tests; Requires Studio validation for edge cases. |
| 3.4 (DataModel query) | Complex Roblox type serialization. | Agent implements code + mock tests; Requires Studio validation for real type serialization. |
| 3.5 (terminal dot-commands) | Interactive REPL wiring to adapter registry. | Agent implements; review agent verifies dispatch pattern and dot-command coverage. |
| 5.1 (MCP scaffold + mcp command) | MCP server lifecycle, BridgeConnection integration. Uses `@modelcontextprotocol/sdk` (decided in `06-mcp-server.md`). | Agent implements; Claude Code validation is a separate step. |
| 6.2 (e2e tests) | Orchestrating multi-process integration tests. | Skilled agent implements with full codebase context. |
| 6.3 (migration guide) | Technical writing requiring understanding of user workflows. | Agent writes; review agent verifies completeness and accuracy against implementation. |

### Recommended execution order for a single developer

If only one developer is available, the recommended sequence is:

1. Tasks 0.1-0.4, 1.1, 1.2 (output modes + protocol + pending requests, can interleave -- Phase 0 touches a different package so there are no conflicts)
2. Task 1.3 (bridge module -- largest foundation task, start early)
3. Tasks 1.4, 1.5, 1.8 (integrate foundation + failover -- 1.8 can proceed in parallel with 1.4/1.5)
4. Tasks 1.6, 1.9, 1.10 (action dispatch + failover tests + observability)
5. Task 1.7 (command handler infra -- integrates output modes from Phase 0)
6. Task 2.1 (persistent plugin -- start early, it is the longest single task)
7. Tasks 2.2, 2.3, 2.4 (plugin manager + install commands), 2.5 (complete Phase 2)
8. Tasks 2.6, 2.7 (CLI session support)
9. Tasks 3.1, 3.2, 3.3, 3.4 (actions)
10. Task 3.5 (terminal integration)
11. Tasks 4.1, 4.2, 4.3 (split server -- now much simpler, mostly wiring)
12. Tasks 5.1, 5.2, 5.3 (MCP)
13. Tasks 6.1-6.5 (polish)

### Recommended assignment for two agents working in parallel

**Agent A** (TypeScript server-side + bridge module + output modes + failover):
0.1-0.4 (output modes) -> 1.1 -> 1.2 -> 1.3 (bridge module) -> 1.8 (failover impl) -> 1.9 (failover tests) -> 1.5 -> 1.6 -> 2.3 -> 3.1 -> 3.3 -> 4.1 -> 4.2 -> 4.3 -> 5.1 -> 5.2 -> 5.3

**Agent B** (Luau plugin + CLI focus + observability):
1.10 (failover observability, after A completes 1.8) -> 1.4 (StudioBridge wrapper, after A completes 1.3) -> 1.7 (command handler infra, after A completes 0.1-0.4 and 1.3) -> 2.1 -> 2.2 -> 2.4 (plugin manager + install commands) -> 2.5 -> 2.6 -> 2.7 -> 3.2 -> 3.4 -> 3.5 -> 6.1 -> 6.2

Sync points: Agent B waits for Agent A to complete 1.1 before starting 2.1. Agent B waits for Agent A to complete 1.3 before starting 1.4. Agent B waits for Agent A to complete 1.8 before starting 1.10. Agent B waits for Agent A to complete 0.1-0.4 and 1.3 before starting 1.7. Agent B waits for Agent A to complete 1.6 before starting 3.2/3.4. Agent A must complete 1.9 (failover tests passing) before either agent starts Phase 2.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 6.1 (update tests) | Refactored code breaks existing tests in ways that are not obvious (e.g., timing changes, different error messages) | Self-fix: fix the tests to match the new behavior. If the new behavior is wrong, fix the implementation. |
| 6.1 (update tests) | v2 handshake tests conflict with existing v1 handshake tests | Self-fix: ensure both v1 and v2 paths are tested independently. Do not remove v1 tests. |
| 6.2 (e2e tests) | Mock plugin client does not accurately simulate real plugin behavior | Escalate: the mock should be reviewed against real Studio plugin behavior. If the mock diverges significantly, it will produce false confidence. |
| 6.2 (e2e tests) | E2e tests are too slow (> 60 seconds per test) due to real timeouts | Self-fix: use shorter timeouts in test configuration. Add `testTimeoutMs` override for e2e test suites. |
| 6.3 (migration guide) | Documentation references APIs that changed during implementation | Self-fix: review all code samples in the guide against the actual implementation before publishing. |
| 6.4 (index.ts exports) | Exporting internal types accidentally creates a public API commitment | Escalate: review the export list against the tech spec. Only export types listed in `07-bridge-network.md` section 2.1. |
| 6.5 (CI integration) | `CI=true` detection interferes with non-CI environments that happen to set this variable | Self-fix: use `CI=true` (the standard convention). Document that `CI=true` forces ephemeral plugin mode. Add `--prefer-persistent-plugin` flag to override. |
