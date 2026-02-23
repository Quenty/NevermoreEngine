# Phase 1b: Failover & Bridge Networking -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)
**Validation**: [studio-bridge/plans/execution/validation/01-bridge-network.md](../validation/01-bridge-network.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

These tasks were split out from Phase 1 because they involve cross-process coordination and failover logic that benefits from independent scheduling. Tasks 1.8 and 1.9 require a skilled agent with review agent verification for testing correctness. Task 1.10 is an integration test suite that depends on both.

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)

---

## Task 1.8: Failover Detection and Host Takeover

**Prerequisites**: Task 1.3a (transport layer and bridge host) must be completed first.

**Context**: Studio-bridge uses a single bridge host process (on port 38741) that all plugins and CLI clients connect to. When that process dies -- gracefully via SIGTERM/SIGINT, or violently via kill -9 or crash -- every participant is affected simultaneously. This task implements the failover detection and host takeover protocol: the mechanism by which a surviving CLI client detects the host's death, races to bind the port, and promotes itself to become the new host. This is the most critical resilience mechanism in the system. Without it, every host death requires manual intervention.

The takeover protocol has two paths: **graceful** (host sends `HostTransferNotice` before dying, clients skip jitter and takeover immediately) and **crash** (no notification, clients detect WebSocket disconnect, apply random jitter to avoid thundering herd, then race to bind). Both paths converge on the same promotion logic. The OS guarantees that `bind()` is atomic -- exactly one client wins the port, and the rest fall back to connecting as clients to the new host.

**Objective**: Implement the failover state machine in `hand-off.ts` and integrate it into `bridge-host.ts` (graceful shutdown) and `bridge-client.ts` (disconnect detection and takeover). Write unit tests for the state machine transitions and jitter behavior.

**Read First**:
- `studio-bridge/plans/tech-specs/08-host-failover.md` (the authoritative spec -- read the whole thing)
- `studio-bridge/plans/tech-specs/07-bridge-network.md` sections 5.4-5.6 (host-protocol.ts, bridge-host.ts, bridge-client.ts, hand-off.ts)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/transport-server.ts` (existing transport, needed for port binding)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (existing host, you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (existing client, you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/host-protocol.ts` (existing protocol types including `HostTransferNotice`)

**Files to Create**:
- `src/bridge/internal/hand-off.ts` -- takeover logic (jitter, bind, promote), graceful shutdown coordination
- `src/bridge/internal/hand-off.test.ts` -- unit tests for state machine and jitter

**Files to Modify**:
- `src/bridge/internal/bridge-host.ts` -- register SIGTERM/SIGINT handlers, implement `shutdownAsync()` with `HostTransferNotice` broadcast, 2-second shutdown timeout, idempotent shutdown guard
- `src/bridge/internal/bridge-client.ts` -- disconnect detection, classify graceful vs crash, invoke hand-off takeover, role transition from client to host
- `src/bridge/internal/transport-server.ts` -- ensure `SO_REUSEADDR` is set (Node.js does this by default, add a defensive comment), add `forceClose()` method for crash simulation in tests

**TypeScript Interfaces**:

The `HostTransferNotice` message is already defined in `host-protocol.ts`:

```typescript
interface HostTransferNotice {
  type: 'host-transfer';
  // Sent by the host to all clients when it is shutting down gracefully
}

interface HostReadyNotice {
  type: 'host-ready';
  // Sent by the new host to remaining clients after takeover
}
```

The takeover state machine in `hand-off.ts` uses these states:

```typescript
type TakeoverState =
  | 'connected'           // Normal operation, connected to host
  | 'detecting-failure'   // WebSocket closed/errored, determining failure type
  | 'taking-over'         // Jitter complete, attempting to bind port
  | 'promoted'            // Successfully bound port, now acting as host
  | 'fell-back-to-client' // Bind failed (EADDRINUSE), reconnected as client to new host
  ;
```

Export a `HandOffManager` class (or equivalent) with this shape:

```typescript
export class HandOffManager {
  constructor(options: { port: number });

  /** Current takeover state. */
  get state(): TakeoverState;

  /**
   * Called when the host sends HostTransferNotice (graceful path).
   * Sets _takeoverPending = true. Does NOT initiate takeover yet --
   * that happens when the WebSocket actually closes.
   */
  onHostTransferNotice(): void;

  /**
   * Called when the WebSocket to the host closes or errors.
   * Determines graceful vs crash based on whether onHostTransferNotice()
   * was called first, then initiates the appropriate takeover path.
   * Returns the outcome: 'promoted' or 'fell-back-to-client'.
   */
  onHostDisconnectedAsync(): Promise<'promoted' | 'fell-back-to-client'>;
}
```

**State Machine -- Guard Conditions**:

| Transition | Guard | Notes |
|---|---|---|
| `connected` -> `detecting-failure` | WebSocket `close` or `error` event fires | Entry into failover |
| `detecting-failure` -> `taking-over` | Jitter delay complete | 0ms for graceful (HostTransferNotice received), uniformly random [0, 500ms] for crash |
| `taking-over` -> `promoted` | `server.listen(port)` succeeds (bind succeeds) | This process is now the host |
| `taking-over` -> `fell-back-to-client` | Bind fails with EADDRINUSE AND subsequent WebSocket connect to `ws://localhost:port/client` succeeds | Another client won the race |
| `taking-over` -> `taking-over` | Bind fails with EADDRINUSE AND client connect also fails | Retry after 1 second (port in TIME_WAIT or held by foreign process). Up to 10 retries. |
| `taking-over` -> ERROR | 10 retries exhausted | Throw `HostUnreachableError` |

**Error transitions**: If `bind()` fails with an error other than EADDRINUSE, throw immediately (do not retry -- this is a system-level error like EACCES). If bind succeeds but the subsequent host startup fails (e.g., `BridgeHost` constructor throws), call `server.close()` to release the port and fall back to the retry loop.

**Implementation Steps**:

1. Create `hand-off.ts` with the `HandOffManager` class and a pure `computeTakeoverJitterMs(options: { graceful: boolean }): number` function.
2. `computeTakeoverJitterMs`: returns `0` if `graceful` is true; otherwise returns `Math.random() * 500` (uniformly distributed [0, 500ms]). This is the ONLY source of randomness in the failover path. Export it so tests can validate the range.
3. Implement `onHostTransferNotice()`: set `_takeoverPending = true`, set state to `detecting-failure`.
4. Implement `onHostDisconnectedAsync()`:
   - a. If `_takeoverPending` is true (graceful path): jitter = 0. Set state to `taking-over`.
   - b. If `_takeoverPending` is false (crash path): compute jitter via `computeTakeoverJitterMs({ graceful: false })`. Wait jitter ms. Set state to `taking-over`.
   - c. Enter retry loop (max 10 attempts):
     - Try `server.listen(port)` to bind port
     - If bind succeeds: set state to `promoted`, return `'promoted'`
     - If EADDRINUSE: try connecting as client to `ws://localhost:port/client`
       - If client connect succeeds: set state to `fell-back-to-client`, return `'fell-back-to-client'`
       - If client connect fails: wait 1 second, continue loop
   - d. If loop exhausts: throw `HostUnreachableError`
5. Modify `bridge-host.ts` to register SIGTERM/SIGINT handlers in `startAsync()`, BEFORE binding the port. Implement `shutdownAsync()`:
   - Guard: `if (this._shuttingDown) return;` then `this._shuttingDown = true;`
   - Send `{ type: 'host-transfer' }` to all connected clients
   - Send WebSocket close frame (code 1001, "Going Away") to all connected plugins
   - Send WebSocket close frame (code 1001) to all connected clients
   - Call `this._transportServer.closeAsync()` to free the port
   - Wrap the above in a 2-second timeout: if shutdown takes longer, call `forceClose()` and exit
6. Modify `bridge-client.ts`:
   - On receiving `{ type: 'host-transfer' }` message: call `this._handOff.onHostTransferNotice()`
   - On WebSocket close/error: call `const outcome = await this._handOff.onHostDisconnectedAsync()`
   - If outcome is `'promoted'`: create a new `BridgeHost`, start it, update `this._role` to `'host'`, reject all pending requests from the old connection with `SessionDisconnectedError`
   - If outcome is `'fell-back-to-client'`: the `HandOffManager` has already established the client connection; update internal state to use the new connection
7. Add `forceClose()` to `transport-server.ts` that closes all sockets immediately without sending close frames (for crash simulation in tests).
8. Ensure `SO_REUSEADDR` is documented in `transport-server.ts` with a comment explaining that Node.js `http.Server` sets it by default and that this MUST NOT be removed in future refactors.

**Race Condition Handling**:

The critical race is: "two clients bind simultaneously after host death." This is resolved by the OS kernel. `bind()` is atomic at the kernel level. If client A and client B both call `bind()` on port 38741 at the same time:
- Exactly one succeeds (gets the port)
- The other gets EADDRINUSE
- The loser then tries connecting as a client to the winner
- No lock files, no distributed coordination, no PIDs -- the port IS the lock

The jitter (0-500ms random delay for crash path only) reduces contention by spreading bind attempts over time, but it is not required for correctness. Even without jitter, the bind-or-fallback loop is correct. The jitter is an optimization to reduce unnecessary EADDRINUSE errors.

**Test Scenarios**:

All timing tests MUST use `vi.useFakeTimers()`. Do NOT use wall-clock assertions or `setTimeout` with real delays.

```typescript
describe('HandOffManager', () => {
  describe('state machine transitions', () => {
    it('starts in connected state', () => {
      const handOff = new HandOffManager({ port: TEST_PORT });
      expect(handOff.state).toBe('connected');
    });

    it('transitions to detecting-failure on HostTransferNotice', () => {
      const handOff = new HandOffManager({ port: TEST_PORT });
      handOff.onHostTransferNotice();
      expect(handOff.state).toBe('detecting-failure');
    });

    it('graceful path: skips jitter, transitions directly to taking-over', async () => {
      // Setup: host running, client connected, mock bind to succeed
      const handOff = createHandOffWithMockBind({ bindResult: 'success' });
      handOff.onHostTransferNotice();
      const outcome = await handOff.onHostDisconnectedAsync();
      expect(outcome).toBe('promoted');
      expect(handOff.state).toBe('promoted');
    });

    it('crash path: applies jitter before takeover attempt', async () => {
      vi.useFakeTimers();
      const handOff = createHandOffWithMockBind({ bindResult: 'success' });
      // Do NOT call onHostTransferNotice -- simulate crash
      const promise = handOff.onHostDisconnectedAsync();
      // Jitter is [0, 500ms], advance past it
      await vi.advanceTimersByTimeAsync(500);
      const outcome = await promise;
      expect(outcome).toBe('promoted');
      vi.useRealTimers();
    });

    it('falls back to client when bind fails and another host exists', async () => {
      const handOff = createHandOffWithMockBind({
        bindResult: 'eaddrinuse',
        clientConnectResult: 'success',
      });
      handOff.onHostTransferNotice();
      const outcome = await handOff.onHostDisconnectedAsync();
      expect(outcome).toBe('fell-back-to-client');
    });

    it('retries when bind fails and no host is reachable', async () => {
      vi.useFakeTimers();
      let attempt = 0;
      const handOff = createHandOffWithMockBind({
        bindResult: () => {
          attempt++;
          return attempt >= 3 ? 'success' : 'eaddrinuse';
        },
        clientConnectResult: 'fail',
      });
      handOff.onHostTransferNotice();
      const promise = handOff.onHostDisconnectedAsync();
      // Advance past retry delays (1s per retry)
      await vi.advanceTimersByTimeAsync(3000);
      const outcome = await promise;
      expect(outcome).toBe('promoted');
      expect(attempt).toBe(3);
      vi.useRealTimers();
    });

    it('throws HostUnreachableError after 10 failed retries', async () => {
      vi.useFakeTimers();
      const handOff = createHandOffWithMockBind({
        bindResult: 'eaddrinuse',
        clientConnectResult: 'fail',
      });
      handOff.onHostTransferNotice();
      const promise = handOff.onHostDisconnectedAsync();
      await vi.advanceTimersByTimeAsync(15000); // 10 retries * 1s each
      await expect(promise).rejects.toThrow(HostUnreachableError);
      vi.useRealTimers();
    });
  });

  describe('computeTakeoverJitterMs', () => {
    it('returns 0 for graceful shutdown', () => {
      expect(computeTakeoverJitterMs({ graceful: true })).toBe(0);
    });

    it('returns values in [0, 500] for crash', () => {
      const values = Array.from({ length: 1000 }, () =>
        computeTakeoverJitterMs({ graceful: false })
      );
      expect(Math.min(...values)).toBeGreaterThanOrEqual(0);
      expect(Math.max(...values)).toBeLessThanOrEqual(500);
    });
  });

  describe('thundering herd', () => {
    it('two clients: host crashes, one takes over, one falls back', async () => {
      // Simulate two HandOffManagers with coordinated mock bind:
      // whichever calls bind first succeeds, the second gets EADDRINUSE
      // ...
    });

    it('graceful shutdown with HostTransferNotice: no jitter', async () => {
      // Both clients receive HostTransferNotice, both try immediately,
      // one wins, one falls back
      // ...
    });

    it('three clients: crash, jitter spreads attempts', async () => {
      vi.useFakeTimers();
      // Track timestamps of bind attempts to verify they are spread
      // over the [0, 500ms] jitter window
      // ...
      vi.useRealTimers();
    });
  });
});

describe('bridge-host shutdown', () => {
  it('sends HostTransferNotice to all clients before closing', async () => {
    // Start host, connect two mock clients, call shutdownAsync()
    // Verify both clients received { type: 'host-transfer' }
  });

  it('shutdown is idempotent', async () => {
    // Call shutdownAsync() twice, verify no error and no duplicate messages
  });

  it('force-closes after 2-second timeout', async () => {
    vi.useFakeTimers();
    // Connect a mock client that never acknowledges close
    // Verify host force-closes after 2 seconds
    vi.useRealTimers();
  });
});
```

**Acceptance Criteria**:

1. `HandOffManager` correctly transitions through all states: `connected` -> `detecting-failure` -> `taking-over` -> `promoted` (or `fell-back-to-client`).
2. Graceful path (HostTransferNotice received): jitter is 0, takeover begins immediately after WebSocket close.
3. Crash path (no HostTransferNotice): jitter is uniformly distributed in [0, 500ms].
4. When bind succeeds: client promotes to host, creates new `BridgeHost`, starts accepting connections.
5. When bind fails with EADDRINUSE and another host exists: client falls back to client role and connects to the new host.
6. When bind fails with EADDRINUSE and no host exists: client retries every 1 second, up to 10 times.
7. After 10 retries: throws `HostUnreachableError`.
8. `shutdownAsync()` on bridge-host sends `HostTransferNotice` to all clients, then closes all connections, then frees the port -- all within a 2-second timeout.
9. Shutdown is idempotent (second call is a no-op).
10. SIGTERM and SIGINT handlers are registered before the port is bound.
11. All pending requests in the client's `PendingRequestMap` are rejected with `SessionDisconnectedError` during promotion.
12. `SO_REUSEADDR` is documented in transport-server.ts.
13. All unit tests pass: `npx vitest run src/bridge/internal/hand-off.test.ts` from `tools/studio-bridge/`.

**Do NOT**:
- Use lock files or PID files for coordination -- the port binding IS the coordination mechanism.
- Add `process.exit()` calls outside of the shutdown timeout handler -- let the normal control flow handle exit.
- Use `setTimeout` with real delays in tests -- use `vi.useFakeTimers()` for all timing.
- Import from `@quenty/` packages in `hand-off.ts` -- this module should be self-contained within `src/bridge/internal/`.
- Add retry logic for non-EADDRINUSE bind errors (EACCES, etc.) -- those are fatal.
- Forget `.js` extensions on local imports.

---

## Task 1.9: Inflight Request Handling During Failover

**Prerequisites**: Tasks 1.3d5 (BridgeConnection barrel export) and 1.8 (failover detection and host takeover) must be completed first.

**Context**: When the bridge host dies mid-operation, there may be in-flight requests that were sent to the host but never received a response. These requests are sitting in the client's `PendingRequestMap` as unresolved promises. The consumers that initiated those requests (CLI commands, MCP tools, library calls) are waiting on those promises. This task ensures that inflight requests are surfaced to callers quickly and correctly -- with the right error type, within the right time bounds, and with the right retry semantics.

The key distinction: consumers should receive `SessionDisconnectedError` (the host died), NOT `ActionTimeoutError` (the request timed out). The difference matters because `ActionTimeoutError` implies "we waited the full timeout and nothing happened" while `SessionDisconnectedError` implies "the host died and the request outcome is unknown." Consumer code makes retry decisions based on this distinction.

**Objective**: Implement inflight request rejection during host death, define retry policy per action type, and write tests verifying that requests surface the correct error within 2 seconds of host death.

**Read First**:
- `studio-bridge/plans/tech-specs/08-host-failover.md` sections 3.1, 4.4, 5.4 (state loss, drain behavior, host dies mid-action)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (client-side pending request handling)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/pending-request-map.ts` (the PendingRequestMap class from Task 1.2)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-session.ts` (BridgeSession action methods)
- `studio-bridge/plans/tech-specs/07-bridge-network.md` section 2.7 (error types)

**Files to Modify**:
- `src/bridge/internal/bridge-client.ts` -- on host disconnect, call `_pendingRequests.rejectAll()` with `SessionDisconnectedError` before entering the takeover flow
- `src/bridge/bridge-session.ts` -- when the underlying transport handle is disconnected, action methods must reject immediately with `SessionDisconnectedError` (not queue or hang)
- `src/bridge/errors.ts` -- ensure `SessionDisconnectedError` is defined with a clear message

**Files to Create**:
- `src/bridge/internal/__tests__/failover-inflight.test.ts` -- tests for inflight request behavior during failover

**PendingRequestMap Behavior During Host Death**:

When the client detects host disconnect (WebSocket close/error event), it MUST call `_pendingRequests.cancelAll('Host disconnected')` BEFORE initiating the takeover flow. The `cancelAll` method (from Task 1.2) rejects every pending promise with the provided reason, clears all timeout timers, and empties the map. The `bridge-client.ts` should wrap the cancellation reason in a `SessionDisconnectedError`:

```typescript
private _onHostDisconnected(): void {
  // Step 1: Reject all inflight requests immediately
  this._pendingRequests.rejectAll(
    new SessionDisconnectedError('Bridge host disconnected during request')
  );

  // Step 2: Begin takeover flow (may take seconds)
  this._handOff.onHostDisconnectedAsync().then(outcome => {
    // ... handle promotion or fallback ...
  });
}
```

The ordering is critical: reject first, THEN takeover. If takeover happens first, the pending requests sit unresolved for the entire takeover duration (jitter + bind + retry = potentially seconds). Consumers should learn about the failure immediately.

**How Inflight Requests Are Surfaced to Callers**:

The error propagation chain:

1. Host dies -> WebSocket close event fires on the client
2. Client calls `_pendingRequests.rejectAll(new SessionDisconnectedError(...))`
3. Each pending promise rejects with `SessionDisconnectedError`
4. The consumer's `await session.execAsync(...)` (or other action method) throws `SessionDisconnectedError`
5. Consumer can catch and decide whether to retry

**Retry Policy Per Action Type**:

NOT all actions should be retried automatically. The retry decision depends on whether the action is idempotent:

| Action | Auto-retry after failover? | Reason |
|--------|---------------------------|--------|
| `execute` (exec) | **NO** | Arbitrary Luau code may have side effects. The script may have partially executed. Retrying could cause double execution. |
| `run` | **NO** | Same as execute -- arbitrary code with potential side effects. |
| `queryState` | **YES** | Read-only, idempotent. Safe to retry on the new host once a session is available. |
| `captureScreenshot` | **YES** | Read-only, idempotent. |
| `queryDataModel` | **YES** | Read-only, idempotent. |
| `queryLogs` | **YES** | Read-only, idempotent. The plugin's log buffer survives host death. |
| `subscribe` | **YES** | Idempotent (subscribing to an already-subscribed event is a no-op on the plugin). |

Auto-retry for idempotent actions is NOT implemented in this task -- it would be a higher-level concern in `BridgeSession` or consumer code. This task only ensures the correct error type is thrown so that consumers CAN make the retry decision. Document the retry policy in code comments on `SessionDisconnectedError`.

**BridgeSession Behavior After Disconnect**:

Once a `BridgeSession`'s transport handle is disconnected, ALL subsequent action calls MUST reject immediately with `SessionDisconnectedError`. The session must not queue, buffer, or silently drop requests. Implement this with a `_disconnected` flag on the session:

```typescript
async execAsync(code: string, timeout?: number): Promise<ExecResult> {
  if (this._disconnected) {
    throw new SessionDisconnectedError(
      `Session ${this.info.sessionId} is disconnected (host died). ` +
      `Re-resolve session via BridgeConnection.waitForSession().`
    );
  }
  // ... normal implementation ...
}
```

When the client transitions roles (during takeover), it should mark ALL existing `BridgeSession` instances as disconnected and emit `'session-disconnected'` events. New sessions from the new host will be fresh `BridgeSession` instances with new session IDs.

**Test Scenarios**:

```typescript
describe('inflight request handling during failover', () => {
  it('rejects pending execute with SessionDisconnectedError on host death', async () => {
    // Setup: host + client + mock plugin
    const { host, client, plugin } = await setupTestBridge();

    // Send execute, but mock plugin does NOT respond (simulates in-flight)
    const execPromise = client.session.execAsync('print("hello")');

    // Kill the host (force close, no HostTransferNotice)
    host.forceClose();

    // The exec promise should reject with SessionDisconnectedError
    await expect(execPromise).rejects.toThrow(SessionDisconnectedError);
    // NOT ActionTimeoutError -- the error should arrive quickly
  });

  it('rejects pending execute within 2 seconds of host death', async () => {
    const { host, client, plugin } = await setupTestBridge();
    const execPromise = client.session.execAsync('print("hello")');
    const startTime = Date.now();

    host.forceClose();

    try {
      await execPromise;
    } catch (err) {
      const elapsed = Date.now() - startTime;
      expect(elapsed).toBeLessThan(2000);
      expect(err).toBeInstanceOf(SessionDisconnectedError);
    }
  });

  it('rejects ALL pending requests, not just the first', async () => {
    const { host, client, plugin } = await setupTestBridge();

    // Send 5 concurrent requests, none answered
    const promises = Array.from({ length: 5 }, (_, i) =>
      client.session.execAsync(`print(${i})`)
    );

    host.forceClose();

    const results = await Promise.allSettled(promises);
    for (const result of results) {
      expect(result.status).toBe('rejected');
      expect((result as PromiseRejectedResult).reason).toBeInstanceOf(SessionDisconnectedError);
    }
  });

  it('queryState retries successfully after new host takes over', async () => {
    const { host, client, plugin } = await setupTestBridge();

    // Send queryState, host dies mid-request
    const queryPromise = client.session.queryStateAsync();
    host.forceClose();

    // First attempt fails
    await expect(queryPromise).rejects.toThrow(SessionDisconnectedError);

    // Wait for client to become new host and plugin to reconnect
    await waitForCondition(() => client.role === 'host', 5000);
    await plugin.waitForReconnection(5000);

    // Get the new session and retry (consumer-side retry for idempotent action)
    const newSession = await client.waitForSession(5000);
    const state = await newSession.queryStateAsync();
    expect(state.state).toBeDefined();
  });

  it('session methods reject immediately after disconnect', async () => {
    const { host, client } = await setupTestBridge();
    const session = client.session;

    host.forceClose();
    // Wait for disconnect to be detected
    await waitForCondition(() => !session.isConnected, 2000);

    // All subsequent calls should reject immediately
    await expect(session.execAsync('print(1)')).rejects.toThrow(SessionDisconnectedError);
    await expect(session.queryStateAsync()).rejects.toThrow(SessionDisconnectedError);
    await expect(session.captureScreenshotAsync()).rejects.toThrow(SessionDisconnectedError);
  });

  it('graceful shutdown: pending requests reject with SessionDisconnectedError', async () => {
    const { host, client, plugin } = await setupTestBridge();
    const execPromise = client.session.execAsync('print("hello")');

    // Graceful shutdown (sends HostTransferNotice first)
    await host.shutdownAsync();

    await expect(execPromise).rejects.toThrow(SessionDisconnectedError);
  });
});
```

**Acceptance Criteria**:

1. When the host dies (graceful or crash), ALL pending requests in the client's `PendingRequestMap` are rejected with `SessionDisconnectedError` within 2 seconds.
2. The error type is `SessionDisconnectedError`, NOT `ActionTimeoutError`.
3. Pending requests are rejected BEFORE the takeover flow begins (ordering guarantee).
4. After disconnect, all action methods on the old `BridgeSession` throw `SessionDisconnectedError` immediately.
5. After failover, consumers can get a new `BridgeSession` via `bridge.waitForSession()` and retry idempotent actions.
6. `SessionDisconnectedError` message includes the session ID and guidance to re-resolve via `waitForSession()`.
7. All tests pass: `npx vitest run src/bridge/internal/__tests__/failover-inflight.test.ts` from `tools/studio-bridge/`.

**Do NOT**:
- Implement automatic retry logic in this task -- that is a consumer-level concern. This task only ensures the right error is thrown.
- Let pending requests hang until their timeout expires -- they must be rejected eagerly on disconnect.
- Use `ActionTimeoutError` for host death scenarios -- that error is reserved for "the plugin did not respond within the timeout while the host was alive."
- Forget to clear timeout timers when rejecting pending requests (timer leaks will cause test warnings).
- Forget `.js` extensions on local imports.

---

## Task 1.10: Plugin Reconnection During Failover

**Prerequisites**: Tasks 1.3d5 (BridgeConnection barrel export) and 1.8 (failover detection and host takeover) must be completed first.

**Context**: When the bridge host dies, Studio plugins lose their WebSocket connection. The persistent plugin has a built-in state machine (implemented in Luau) that handles reconnection: it detects the disconnect, enters a backoff period, then polls the health endpoint to discover the new host. This task implements the **server-side handling** of plugin reconnection after failover, and writes integration tests that exercise the full reconnection flow using mock plugins. It also covers the mock plugin's reconnection behavior for use in all failover tests.

The critical insight: the new host starts with an **empty session map**. It has zero knowledge of what sessions existed on the old host. Sessions are rebuilt entirely from plugin re-registrations. This means there is a recovery window (1-5 seconds) where `listSessions()` returns fewer sessions than actually exist. The tests must verify this progressive recovery behavior.

**Objective**: Extend the mock plugin helper with reconnection support, implement server-side reconnection handling in `bridge-host.ts`, and write integration tests covering plugin reconnection scenarios during both graceful and crash failover.

**Read First**:
- `studio-bridge/plans/tech-specs/08-host-failover.md` sections 2.1-2.4, 3.3, 3.4 (recovery protocol, state recovery, instance ID continuity)
- `studio-bridge/plans/tech-specs/03-persistent-plugin.md` sections 4.1-4.2, 6.1-6.4 (plugin state machine, reconnection strategy)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (host -- handles plugin connections)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/session-tracker.ts` (session management)
- Any existing mock plugin helpers from prior tasks

**Files to Create**:
- `src/bridge/internal/__tests__/failover-plugin-reconnect.test.ts` -- integration tests for plugin reconnection
- `src/bridge/internal/__tests__/helpers/mock-plugin.ts` -- extended mock plugin with reconnection support (or modify existing if one exists)

**Files to Modify**:
- `src/bridge/internal/bridge-host.ts` -- ensure `register` messages from reconnecting plugins are handled correctly (fresh session created, old session was already removed when WebSocket closed)

**Plugin State Machine During Host Death**:

The real Luau plugin transitions through these states during failover (you do not implement the Luau side -- the mock plugin simulates it):

```
connected                     -- Normal operation, WebSocket active
    |
    | WebSocket close/error (no shutdown message preceded it)
    v
reconnecting                  -- Backoff period before retrying
    |
    | backoff timer expires (1s initially, doubles: 2s, 4s, 8s, 16s, 30s max)
    v
searching                     -- Polling /health every 2 seconds
    |
    | /health returns 200
    v
connecting                    -- Opening WebSocket, sending register
    |
    | welcome received
    v
connected                     -- Re-established on the new host
```

For **graceful** shutdown (clean WebSocket close with code 1001): the plugin skips `reconnecting` and goes directly to `searching` with no backoff.

For **crash** (unexpected close/error): the plugin enters `reconnecting` with exponential backoff starting at 1 second: 1s, 2s, 4s, 8s, 16s, 30s (capped).

**Mock Plugin Reconnection Support**:

Extend the mock plugin helper (from Task 1.3 or create new) with auto-reconnection:

```typescript
export interface MockPluginOptions {
  port: number;
  instanceId?: string;      // Default: random UUID
  context?: SessionContext;  // Default: 'edit'
  placeName?: string;        // Default: 'TestPlace'
  placeId?: number;          // Default: 0
  gameId?: number;           // Default: 0
  capabilities?: Capability[];
  autoReconnect?: boolean;   // Default: true
  pollIntervalMs?: number;   // Default: 200 (fast for tests, real plugin uses 2000)
  backoffMs?: number;        // Default: 100 (fast for tests, real plugin uses 1000)
}

export interface MockPlugin {
  readonly state: 'disconnected' | 'connecting' | 'connected' | 'reconnecting' | 'searching';
  readonly sessionId: string | null;
  readonly instanceId: string;
  readonly context: SessionContext;

  /** Connect to the host for the first time. */
  connectAsync(): Promise<void>;

  /** Wait for the welcome message. */
  waitForWelcome(timeoutMs?: number): Promise<void>;

  /** Wait for reconnection to complete after a disconnection. */
  waitForReconnection(timeoutMs?: number): Promise<void>;

  /** Register a handler for a specific action type. */
  onAction(type: string, handler: (msg: any) => any): void;

  /** Disconnect and stop the mock plugin. */
  dispose(): void;
}
```

The mock plugin's reconnection behavior:
1. On WebSocket close/error: transition to `reconnecting`
2. After `backoffMs` delay: transition to `searching`
3. Poll `http://localhost:{port}/health` every `pollIntervalMs`
4. On 200 OK: transition to `connecting`, open new WebSocket to `/plugin`
5. Generate a **fresh UUID** as the proposed session ID (per spec: "each plugin generates a fresh UUID as its proposed session ID when re-registering")
6. Send `register` with the same `instanceId` and `context` (these do not change across reconnections)
7. On `welcome`: transition to `connected`, store new session ID from welcome response
8. Reset all subscription state (the new host has no memory of previous subscriptions)

**Session Identity After Reconnection**:

This is a critical design decision that the tests must validate:

- `instanceId` is **persistent** -- the same before and after failover. It identifies the Studio installation.
- `sessionId` is **ephemeral** -- a fresh UUID is generated on each connection. After failover, the session ID changes.
- `context` is **persistent** -- `'edit'`, `'client'`, or `'server'` does not change.
- The tuple `(instanceId, context)` provides continuity across failovers. The `sessionId` does not.

On the server side (bridge-host.ts), when a plugin reconnects:
- The old session was already removed when the old host died (or when the WebSocket closed)
- The new `register` message creates a brand new `TrackedSession` in the `SessionTracker`
- The `SessionTracker` groups sessions by `instanceId` -- the reconnecting plugin slots back into the correct instance group
- The new host emits `SessionEvent { event: 'connected' }` to all connected clients

**Test Scenarios**:

```typescript
describe('plugin reconnection during failover', () => {
  it('plugin reconnects to new host after crash', async () => {
    // Start host, connect mock plugin, connect client
    const host = await createTestHost({ port: 0 });
    const port = host.port;
    const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    await plugin.connectAsync();
    await plugin.waitForWelcome();
    const oldSessionId = plugin.sessionId;

    const client = await BridgeConnection.connectAsync({ port });
    expect(client.listSessions()).toHaveLength(1);

    // Kill the host
    host.forceClose();

    // Wait for client to take over
    await waitForCondition(() => client.role === 'host', 5000);

    // Wait for plugin to reconnect to the new host
    await plugin.waitForReconnection(5000);

    // Session ID should be different (fresh UUID on reconnect)
    expect(plugin.sessionId).not.toBe(oldSessionId);

    // Instance ID should be the same
    expect(plugin.instanceId).toBe('inst-1');

    // The new host should have the session
    const sessions = client.listSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].instanceId).toBe('inst-1');
    expect(sessions[0].context).toBe('edit');
  });

  it('plugin reconnects after graceful shutdown (no backoff)', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;
    const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    await plugin.connectAsync();
    await plugin.waitForWelcome();

    const client = await BridgeConnection.connectAsync({ port });

    // Graceful shutdown
    await host.shutdownAsync();

    // Client takes over
    await waitForCondition(() => client.role === 'host', 5000);

    // Plugin should reconnect quickly (no backoff for graceful)
    await plugin.waitForReconnection(3000);

    expect(client.listSessions()).toHaveLength(1);
  });

  it('multi-context: all 3 sessions reconnect after failover', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;

    // Simulate a Studio in Play mode: 3 plugin instances, same instanceId
    const editPlugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    const serverPlugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'server' });
    const clientPlugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'client' });

    await Promise.all([
      editPlugin.connectAsync().then(() => editPlugin.waitForWelcome()),
      serverPlugin.connectAsync().then(() => serverPlugin.waitForWelcome()),
      clientPlugin.connectAsync().then(() => clientPlugin.waitForWelcome()),
    ]);

    const client = await BridgeConnection.connectAsync({ port });
    expect(client.listSessions()).toHaveLength(3);

    // Kill the host
    host.forceClose();

    // Client takes over
    await waitForCondition(() => client.role === 'host', 5000);

    // All 3 plugins reconnect independently
    await Promise.all([
      editPlugin.waitForReconnection(5000),
      serverPlugin.waitForReconnection(5000),
      clientPlugin.waitForReconnection(5000),
    ]);

    // All 3 sessions restored, grouped by instanceId
    const sessions = client.listSessions();
    expect(sessions).toHaveLength(3);
    const contexts = sessions.map(s => s.context).sort();
    expect(contexts).toEqual(['client', 'edit', 'server']);
    // All share the same instanceId
    expect(new Set(sessions.map(s => s.instanceId)).size).toBe(1);
  });

  it('plugin resets subscription state after reconnection', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;
    const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    await plugin.connectAsync();
    await plugin.waitForWelcome();

    const client = await BridgeConnection.connectAsync({ port });
    const session = await client.waitForSession();

    // Subscribe to stateChange
    await session.subscribeAsync(['stateChange']);

    // Kill the host
    host.forceClose();

    // Wait for recovery
    await waitForCondition(() => client.role === 'host', 5000);
    await plugin.waitForReconnection(5000);

    // After reconnection, the new host has no subscription state
    // Consumer must re-subscribe
    const newSession = await client.waitForSession();
    // Verify: the new host does not push stateChange events without re-subscribe
    // (implementation-specific assertion)
  });

  it('actions work through the new host after plugin reconnection', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;
    const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    await plugin.connectAsync();
    await plugin.waitForWelcome();

    // Register a queryState handler on the mock plugin
    plugin.onAction('queryState', () => ({
      type: 'stateResult',
      payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 },
    }));

    const client = await BridgeConnection.connectAsync({ port });

    // Kill host, wait for recovery
    host.forceClose();
    await waitForCondition(() => client.role === 'host', 5000);
    await plugin.waitForReconnection(5000);

    // Execute action through the new host
    const newSession = await client.waitForSession(5000);
    const state = await newSession.queryStateAsync();
    expect(state.state).toBe('Edit');
  });

  it('partial multi-context recovery: available sessions are usable while others reconnect', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;

    const editPlugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit', backoffMs: 50 });
    const serverPlugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'server', backoffMs: 5000 }); // Slow reconnect

    await Promise.all([
      editPlugin.connectAsync().then(() => editPlugin.waitForWelcome()),
      serverPlugin.connectAsync().then(() => serverPlugin.waitForWelcome()),
    ]);

    const client = await BridgeConnection.connectAsync({ port });

    host.forceClose();
    await waitForCondition(() => client.role === 'host', 5000);

    // Edit plugin reconnects quickly
    await editPlugin.waitForReconnection(2000);

    // At this point, 1 of 2 sessions is available
    const sessions = client.listSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].context).toBe('edit');

    // Server plugin eventually reconnects
    await serverPlugin.waitForReconnection(10000);
    expect(client.listSessions()).toHaveLength(2);
  });

  it('no clients: plugin polls until new CLI starts', async () => {
    const host = await createTestHost({ port: 0 });
    const port = host.port;
    const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
    await plugin.connectAsync();
    await plugin.waitForWelcome();

    // Kill host with no clients connected
    host.forceClose();

    // Plugin enters searching state
    await waitForCondition(() => plugin.state === 'searching', 5000);

    // Start a new host on the same port
    const newHost = await createTestHost({ port });

    // Plugin discovers and reconnects
    await plugin.waitForReconnection(5000);
    expect(newHost.listSessions()).toHaveLength(1);
  });
});
```

**Acceptance Criteria**:

1. Mock plugin helper supports auto-reconnection with configurable poll interval and backoff.
2. After host crash, plugin enters `reconnecting` -> `searching` -> `connecting` -> `connected`.
3. After graceful shutdown (clean WebSocket close 1001), plugin skips `reconnecting` and goes directly to `searching` (no backoff).
4. Plugin generates a **fresh UUID** as session ID on reconnect (not the old session ID).
5. Plugin sends the **same `instanceId` and `context`** on reconnect.
6. New host creates a fresh `TrackedSession` from the `register` message, grouped by `instanceId`.
7. Multi-context reconnection: all 3 contexts (edit, client, server) reconnect independently and are grouped correctly.
8. Partial recovery: sessions that reconnect first are immediately usable while others are still reconnecting.
9. Subscription state is NOT carried over -- consumers must re-subscribe after failover.
10. Actions work through the new host after plugin reconnection.
11. All tests use ephemeral ports to avoid conflicts.
12. All tests clean up connections in `afterEach`.
13. All tests pass: `npx vitest run src/bridge/internal/__tests__/failover-plugin-reconnect.test.ts` from `tools/studio-bridge/`.

**Do NOT**:
- Implement the Luau-side reconnection logic -- that is a separate task (Phase 0.5). This task implements the mock and the server-side handling.
- Attempt to transfer or restore session state from the old host -- the new host starts empty and rebuilds from registrations.
- Reuse old session IDs after reconnection -- session IDs are ephemeral and scoped to a single host lifetime.
- Use wall-clock time assertions in tests -- use event-driven waits (`waitForCondition`, `waitForReconnection`) with generous timeouts.
- Use the same port across test cases -- always use ephemeral ports (`port: 0`) to prevent test interference.
- Forget `.js` extensions on local imports.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)
- Validation: [studio-bridge/plans/execution/validation/01-bridge-network.md](../validation/01-bridge-network.md)
- Tech specs: `studio-bridge/plans/tech-specs/07-bridge-network.md`, `studio-bridge/plans/tech-specs/08-host-failover.md`
