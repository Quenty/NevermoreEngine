# Phase 1b: Failover

Goal: Make the bridge host resilient to process death via graceful hand-off and crash recovery. This phase is decoupled from the Phase 1 core gate -- it can run in parallel with Phases 2-3 since it only depends on Task 1.3a (transport server and bridge host).

Note: Basic `SessionDisconnectedError` handling (pending actions reject when the WebSocket drops) is part of Phase 1 core (Task 1.3b acceptance criterion). Phase 1b builds the full failover protocol on top: host takeover, client promotion, plugin reconnection.

References:
- Host failover: `studio-bridge/plans/tech-specs/08-host-failover.md`
- Bridge Network layer: `studio-bridge/plans/tech-specs/07-bridge-network.md`
- Protocol: `studio-bridge/plans/tech-specs/01-protocol.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Phase 1 core: `01-bridge-network.md` (Tasks 1.1-1.7b)
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/01-bridge-network.md` (failover tasks)
- Validation: `studio-bridge/plans/execution/validation/01-bridge-network.md` (failover tests)

---

### Task 1.8: Bridge host failover implementation

**Description**: Extract and harden the host failover logic from the bridge module. This task is dedicated to making failover production-ready: graceful shutdown notification via SIGTERM/SIGINT handlers, client takeover after host death, plugin reconnection handling on the new host, `SO_REUSEADDR` (`reuseAddr: true`) on the server socket to avoid TIME_WAIT delays, and timeout handling for inflight requests during host death. This task implements the full protocol described in `08-host-failover.md`.

Full spec: `studio-bridge/plans/tech-specs/08-host-failover.md`

**Files to create or modify**:
- Create: `src/bridge/internal/hand-off.ts` -- implement `GracefulHandOff` (host sends `hostTransfer` to clients, waits for one to send `hostReady`, then shuts down) and `CrashRecoveryHandOff` (clients detect disconnect, apply random jitter 0-500ms, race to bind port).
- Modify: `src/bridge/internal/bridge-host.ts` -- register SIGTERM/SIGINT handlers that trigger graceful hand-off. On plugin reconnection after takeover, accept re-registrations and restore session state.
- Modify: `src/bridge/internal/bridge-client.ts` -- on host disconnect, enter takeover standby: wait for jitter, attempt to bind port. If bind succeeds, promote to host (create `BridgeHost`, send `hostReady` to remaining clients). If bind fails, reconnect as client to the new host.
- Modify: `src/bridge/bridge-session.ts` -- when the underlying transport disconnects during an inflight action, reject all pending requests with `SessionDisconnectedError` (not silent timeout). When the transport reconnects (new host), re-establish session handles.
- Create: `src/bridge/internal/hand-off.test.ts` -- unit tests for hand-off state machine transitions.

**Dependencies**: Task 1.3a (needs transport server and bridge host infrastructure).

**Complexity**: M

**Acceptance criteria**:
- **Graceful shutdown**: when bridge host receives SIGTERM/SIGINT, it sends `hostTransfer` to all connected clients before closing the server socket. First client to bind port 38741 becomes the new host and sends `hostReady` to remaining clients.
- **Crash recovery**: when the bridge host dies without sending `hostTransfer` (kill -9, OOM), clients detect WebSocket disconnect within 2 seconds (via close/error event), wait random jitter (0-500ms), and race to bind port 38741. First to succeed becomes new host.
- **Plugin reconnection**: after host transfer, plugins detect WebSocket close, poll `/health` with exponential backoff (1s, 2s, 4s, 8s, max 30s), and reconnect to the new host. The new host accepts `register` messages from plugins and restores session tracking. A Studio instance in Play mode has 3 sessions (edit, client, server contexts) that each independently reconnect on their own schedule. (The edit instance was already connected before Play mode, but its connection was also severed by the host death.)
- **Multi-context recovery**: the new host correlates re-registrations by `(instanceId, context)`. Instance grouping is rebuilt progressively as each context reconnects. During recovery, `listSessions()` may return partially-populated instance groups.
- **`SO_REUSEADDR`**: server socket sets `reuseAddr: true` so that port 38741 can be rebound immediately after the previous host's socket enters TIME_WAIT. Port rebind succeeds within 1 second of host death on all platforms.
- **Inflight request handling**: any `BridgeSession` action that is in-flight when the host dies is rejected with `SessionDisconnectedError` (not left hanging until timeout). The consumer receives the rejection within 2 seconds of host death.
- **No clients connected**: when the host dies with no clients, the port is freed. Next CLI invocation binds the port and becomes the new host. Plugins reconnect via polling.
- **State machine correctness**: hand-off transitions are deterministic. A client cannot simultaneously be in "takeover standby" and "connected as client". The state machine has exactly three states: `connected`, `taking-over`, `promoted`.
- Unit tests for hand-off state machine transitions (graceful path, crash path, no-clients path) pass.

### Task 1.9: Failover integration tests

**Description**: Comprehensive integration tests for the bridge host failover protocol. These tests verify that the full failover flow works end-to-end with mock plugins and multiple bridge connections. They cover both graceful and crash failover, timing assertions, inflight request behavior, and plugin reconnection. This is the primary quality gate for the networking layer's resilience -- failover bugs will be painful to debug in production, so the test suite must be thorough.

Full spec: `studio-bridge/plans/tech-specs/08-host-failover.md`

**Files to create**:
- `src/bridge/internal/__tests__/failover-graceful.test.ts` -- tests for graceful host shutdown and client takeover.
- `src/bridge/internal/__tests__/failover-crash.test.ts` -- tests for unclean host death and crash recovery.
- `src/bridge/internal/__tests__/failover-plugin-reconnect.test.ts` -- tests for plugin reconnection to the new host after failover.
- `src/bridge/internal/__tests__/failover-inflight.test.ts` -- tests for inflight request behavior during failover.
- `src/bridge/internal/__tests__/failover-timing.test.ts` -- timing assertions for recovery bounds.

**Dependencies**: Tasks 1.3d5, 1.8 (full bridge module and failover implementation must exist).

**Complexity**: M

**Acceptance criteria**:
- **Graceful shutdown test**: start bridge host + bridge client + mock plugin. Host calls `disconnectAsync()`. Verify: client receives `hostTransfer`, client rebinds port within 2 seconds, client sends `hostReady`, plugin reconnects to new host within 5 seconds, actions work through the new host.
- **Hard kill test**: start bridge host + bridge client + mock plugin. Kill the host (close transport server without sending `hostTransfer`). Verify: client detects disconnect, client becomes new host within 5 seconds, plugin reconnects, actions work.
- **Inflight request test**: start bridge host + bridge client + mock plugin. Client sends an action through the host. While the action is in-flight (mock plugin has not responded), kill the host. Verify: the inflight action rejects with `SessionDisconnectedError` (not `ActionTimeoutError`), and the rejection happens within 2 seconds of host death.
- **TIME_WAIT recovery test**: start bridge host on port X. Stop the host. Immediately start a new host on the same port X. Verify: port bind succeeds within 1 second (thanks to `SO_REUSEADDR`). No `EADDRINUSE` error.
- **Rapid restart test**: start bridge host + mock plugin. Kill the host. Within 3 seconds, start a new CLI command that needs the bridge. Verify: new CLI becomes host, plugin reconnects, command executes successfully -- all within 5 seconds of the original host's death.
- **No-clients test**: start bridge host + mock plugin (no clients). Stop the host. Start a new CLI. Verify: new CLI becomes host, plugin reconnects.
- **Multiple clients takeover**: start host + 3 clients + mock plugin. Kill host. Verify: exactly one client becomes host, other two reconnect as clients, plugin reconnects, no duplicate sessions.
- **Multi-context failover**: start host + 3 mock plugins sharing the same `instanceId` but with different `context` values (edit, client, server). Kill host. Client takes over. Verify: all 3 context sessions re-register independently, the new host groups them by `instanceId`, and `listSessions()` eventually returns 3 sessions for the instance.
- **Partial multi-context recovery**: same setup as above but one mock plugin (e.g., the client context) delays reconnection. Verify: the other 2 sessions are available immediately, and commands can target them by context while the third is still reconnecting.
- **Jitter prevents thundering herd**: start host + 5 clients. Kill host. Verify: bind attempts are spread over 0-500ms (measure timestamps of bind attempts). No more than one client succeeds in binding.
- All tests use ephemeral ports to avoid conflicts.
- All tests clean up connections in `afterEach`.

### Task 1.10: Failover debugging and observability

**Description**: Implement debugging affordances that make failover issues diagnosable. Failover is the single hardest thing to debug in this architecture because it involves multiple processes, timing races, and state transitions. Without clear observability, developers will waste hours on issues that should take minutes.

**Files to create or modify**:
- Modify: `src/bridge/internal/hand-off.ts` -- add structured debug logging for every state transition: `[bridge:handoff] state=taking-over reason=host-disconnect jitter=342ms`, `[bridge:handoff] state=promoted port=38741 elapsed=487ms`.
- Modify: `src/bridge/internal/bridge-host.ts` -- log when clients connect/disconnect, when plugins connect/disconnect, when `hostTransfer` is sent, when host starts idle shutdown countdown.
- Modify: `src/bridge/internal/bridge-client.ts` -- log when host disconnect is detected, when takeover is attempted, when takeover succeeds/fails, when reconnecting as client to new host.
- Modify: `src/bridge/bridge-connection.ts` -- expose `role` transitions on the `BridgeConnection` instance. Emit events on role change: `'role-changed'` with `{ previousRole, newRole, reason }`.
- Modify: `src/commands/sessions.ts` -- when the bridge host is in the middle of a failover (no host available), print: "Bridge host is recovering. Retry in a few seconds." instead of "No bridge host running."
- Modify: `src/bridge/internal/health-endpoint.ts` -- add `hostUptime` and `lastFailoverAt` fields to the health response so diagnostics can detect recent failovers.

**Dependencies**: Tasks 1.3d5, 1.8.

**Complexity**: S

**Acceptance criteria**:
- All hand-off state transitions produce structured log messages at `debug` level (not visible by default, visible with `--log-level debug` or `STUDIO_BRIDGE_LOG_LEVEL=debug`).
- Log messages include: timestamp, component (`bridge:handoff`, `bridge:host`, `bridge:client`), state transition, relevant context (port, session count, instance count, elapsed time, jitter value). During multi-context recovery, log messages distinguish between individual session reconnections and instance-group completeness.
- `studio-bridge sessions` during failover recovery prints a clear recovery message (not an opaque connection error). When instance groups are partially populated during recovery, the output indicates how many contexts have reconnected per instance (e.g., "2 of 3 contexts reconnected for instance abc-123").
- Health endpoint includes `hostUptime` (ms since host started) and `lastFailoverAt` (ISO 8601 timestamp of last failover, `null` if none).
- `BridgeConnection.role` is updated when a client promotes to host (from `'client'` to `'host'`).
- Error messages for host-unavailable scenarios include actionable guidance: "Bridge host is not reachable. If you just restarted, wait a few seconds for failover to complete."

---

### Parallelization within Phase 1b

Task 1.8 depends only on Task 1.3a (transport and host). Tasks 1.9 and 1.10 depend on Task 1.8 and Task 1.3d5 (full bridge module).

```
Phase 1 core: 1.3a (transport + host) --> 1.8 (failover impl) --> 1.9 (failover tests)
                                                                       |
Phase 1 core: 1.3d5 (BridgeConnection) -----+--------------------------+
                                             |
                                             +--> 1.10 (failover observability)
```

Phase 1b can run entirely in parallel with Phases 2-3. It is NOT a gate for those phases.

---

## Phase 1b Gate

All failover unit tests pass. All failover integration tests pass (graceful, crash, inflight, TIME_WAIT, rapid restart, multi-client, multi-context). Observability logging is in place at debug level.

---

## Testing Strategy (Phase 1b)

**Unit tests** (Task 1.8):
- Hand-off state machine transitions: `connected` -> `taking-over` -> `promoted`, and `connected` -> `taking-over` -> `reconnected-as-client`.
- Graceful path: host sends `hostTransfer`, client receives it, client takes over.
- Crash path: host dies without `hostTransfer`, clients detect disconnect, apply jitter, race to bind.
- No-clients path: host dies, port freed, next CLI binds.

**Integration tests** (Task 1.9):
- Graceful shutdown: host sends `hostTransfer`, client takes over within 2 seconds, plugin reconnects within 5 seconds.
- Hard kill: host dies without notification, client takes over within 5 seconds, plugin reconnects.
- Inflight request during host death: pending actions reject with `SessionDisconnectedError` within 2 seconds (not silent timeout).
- TIME_WAIT recovery: port rebind with `SO_REUSEADDR` succeeds within 1 second.
- Rapid restart: kill host + start new CLI within 3 seconds, command executes successfully.
- Multiple clients: exactly one becomes host, others reconnect as clients, no duplicate sessions.
- Multi-context failover: 3 sessions (edit/client/server) sharing an instanceId all re-register and are grouped correctly.
- Partial multi-context recovery: 2 of 3 sessions available while third reconnects.
- Jitter distribution: bind attempts spread over 0-500ms, preventing thundering herd.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 1.8 (failover impl) | Hand-off state machine has race condition where two clients both promote to host | Self-fix: add mutex/flag to ensure only one promotion attempt per client. Add a multi-client race test. |
| 1.8 (failover impl) | SIGTERM handler interferes with Node.js graceful shutdown, causing hang on exit | Self-fix: ensure handler calls `process.exit()` after hand-off completes or after a safety timeout (e.g., 5s). |
| 1.8 (failover impl) | Plugin reconnection to new host fails because the new host's session tracker does not accept re-registration | Escalate: this is a cross-component issue between the session tracker (1.3b) and the failover logic. The session tracker's `(instanceId, context)` replacement behavior must be verified with the failover flow. |
| 1.8 (failover impl) | `SO_REUSEADDR` does not prevent TIME_WAIT on Windows | Escalate: this is a platform-specific issue. Document the limitation and consider `SO_REUSEPORT` or a port-check retry loop as a workaround. |
| 1.9 (failover tests) | Integration tests are flaky due to timing sensitivity | Self-fix: use generous timeouts in assertions (e.g., "within 5 seconds" not "within 100ms"). Use event-driven waits rather than fixed delays. |
| 1.9 (failover tests) | Tests leave orphaned processes or bound ports, breaking subsequent test runs | Self-fix: use ephemeral ports, add `afterEach` cleanup that force-closes all connections and kills child processes. |
| 1.10 (observability) | Debug logging causes performance regression when enabled | Self-fix: ensure all debug logs are gated behind a level check. Do not construct log message strings unless the level is active. |
| 1.10 (observability) | Health endpoint `lastFailoverAt` field leaks internal timing information | Self-fix: this is intentional for diagnostics. Document that the health endpoint is local-only (not exposed to the internet). |
