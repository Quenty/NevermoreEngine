# Bridge Host Failover: Technical Specification

The bridge host is a single point of failure. Every plugin connection, every client connection, and every in-memory session lives inside one process on port 38741. When that process dies -- gracefully, violently, or anywhere in between -- every participant in the system is affected simultaneously. This document specifies exactly what happens in each failure mode, what each participant must do to recover, and what guarantees the system provides about recovery time.

This spec builds on the hand-off protocol described in `07-bridge-network.md` section 6 (hand-off.ts) and the plugin reconnection logic in `03-persistent-plugin.md` section 6. Those documents describe the mechanisms; this document describes the failure taxonomy, the end-to-end recovery sequences, the edge cases that arise when multiple mechanisms interact, and the testing strategy for validating all of it.

## 1. Failure Taxonomy

The bridge host can fail in five distinct ways. Each produces different observable behavior for plugins and clients, and each constrains what recovery steps are possible.

### 1.1 Graceful shutdown (SIGTERM, Ctrl+C)

**What happens to the host:** The process receives SIGTERM or SIGINT. The Node.js process runs its shutdown handler, which has time to notify all connected participants before closing.

**What the host can do:**
1. Send `host.shutting_down` (a `HostTransferNotice` message) to all connected clients
2. Send WebSocket close frames (code 1001, "Going Away") to all connected plugins
3. Close the HTTP server, releasing the port
4. Exit cleanly

**What clients observe:**
- Receive `HostTransferNotice` message over their `/client` WebSocket
- Then receive a clean WebSocket close (code 1001)
- The close is expected -- the client knows the host is shutting down intentionally

**What plugins observe:**
- Receive a WebSocket close frame (code 1001)
- The plugin transitions from `connected` to `searching` (not `reconnecting`, because the close was clean -- see `03-persistent-plugin.md` section 6.1)
- No backoff delay on clean disconnect; the plugin immediately begins polling `/health`

**Recovery timeline:** Port is freed immediately after the server socket closes. A client can bind the port within milliseconds. Plugin discovers the new host on its next 2-second poll cycle. Total recovery: under 2 seconds.

### 1.2 Hard kill (SIGKILL, kill -9)

**What happens to the host:** The OS terminates the process immediately. No signal handlers run. No cleanup code executes. The TCP connections are torn down by the kernel.

**What the host can do:** Nothing. The process is gone.

**What clients observe:**
- WebSocket `close` or `error` event fires. The exact event depends on timing -- if the kernel sends RST packets, clients see an error; if FIN packets, clients see a close.
- No `HostTransferNotice` was received -- the client knows this was an unexpected death.

**What plugins observe:**
- WebSocket `Closed` or `Error` event fires (Roblox WebSocket API)
- The plugin cannot distinguish between a hard kill and a network failure
- The plugin transitions from `connected` to `reconnecting` (because no `shutdown` message preceded the close)
- Backoff starts at 1 second (see `03-persistent-plugin.md` section 6.2)

**Recovery timeline:** The kernel releases the port after TCP teardown, typically within 100-500ms. However, if the socket was in an active data transfer, the port may enter TIME_WAIT (see section 1.5). Without TIME_WAIT: a client can bind within 1 second. Plugin reconnects within 1-5 seconds depending on backoff position. Total recovery: under 5 seconds.

### 1.3 Crash (unhandled exception, out-of-memory)

**What happens to the host:** The Node.js process terminates due to an uncaught exception, unhandled promise rejection, or an OS-level OOM kill. The process exits with a non-zero code. Like SIGKILL, there is no opportunity for cleanup.

**What the host can do:** If the crash is from an uncaught exception, the `uncaughtException` handler could attempt a brief notification. However, this is unreliable -- the process may be in a corrupted state. The spec treats crash recovery identically to hard kill: assume no notifications were sent.

**What clients observe:** Same as hard kill. WebSocket disconnect with no prior `HostTransferNotice`.

**What plugins observe:** Same as hard kill. WebSocket close/error with no prior `shutdown` message.

**Recovery timeline:** Same as hard kill. Port may or may not enter TIME_WAIT depending on the state of active connections at crash time. Total recovery: under 5 seconds without TIME_WAIT.

**Additional concern:** OOM kills may indicate a systemic resource problem. If the new host also encounters OOM, the system enters a crash loop. This is outside the scope of automatic recovery -- the user must investigate resource usage. The observability section (section 6) covers how to diagnose this.

### 1.4 Port conflict (another process binds 38741)

**What happens:** The bridge host is not running, and another process (not studio-bridge) has bound port 38741. Alternatively, the host was running and died, and a non-bridge process grabbed the port before a client could.

**What clients observe when trying to take over:**
- `bind()` call succeeds (they have the port) OR
- `bind()` fails with EADDRINUSE, and the subsequent client connection attempt to the port fails because the process holding the port is not a bridge host (no WebSocket upgrade, no valid health endpoint)
- After 3 retries at 1-second intervals, the client throws `HostUnreachableError`

**What plugins observe:**
- HTTP health check to `localhost:38741/health` returns either a connection refused, a non-200 status, or invalid JSON (because the non-bridge process does not serve the health endpoint)
- The plugin stays in `searching` state, polling every 2 seconds
- When the port conflict resolves (the other process exits, or the user changes the bridge port), recovery proceeds normally

**Recovery timeline:** Depends entirely on when the port conflict resolves. The system cannot recover automatically while the port is held by a foreign process. If the user specifies `--port <other>`, recovery is immediate.

### 1.5 Network stack issues (TIME_WAIT)

**What happens:** After a hard kill or crash, the OS places the server's TCP connections in TIME_WAIT state. This is a standard TCP behavior designed to prevent delayed packets from a previous connection being misinterpreted as belonging to a new connection. On Linux, TIME_WAIT typically lasts 60 seconds (the `net.ipv4.tcp_fin_timeout` value). On macOS, it is 15-30 seconds.

**What clients observe when trying to bind:**
- `bind()` fails with EADDRINUSE even though no process holds the port
- With `SO_REUSEADDR` set on the server socket (which the bridge host MUST set), this is typically a non-issue -- `SO_REUSEADDR` allows binding to a port in TIME_WAIT
- Without `SO_REUSEADDR`, clients must wait for TIME_WAIT to expire

**What plugins observe:** Same as any host-down scenario. Health checks fail, plugin polls with backoff.

**Mitigation:** The transport server (`transport-server.ts`) MUST set `SO_REUSEADDR` on the server socket before binding. In Node.js with the `http` module, this is the default behavior -- `server.listen()` sets `SO_REUSEADDR` automatically. However, the spec explicitly requires this to prevent future refactors from accidentally removing it.

**Recovery timeline:** With `SO_REUSEADDR` (default): typically under 1 second. Without `SO_REUSEADDR`: up to 60 seconds on Linux, up to 30 seconds on macOS. The system MUST use `SO_REUSEADDR`.

## 2. Recovery Protocol

This section describes the step-by-step recovery sequence from each participant's perspective after the host dies. The sequence differs based on whether the shutdown was graceful (section 2.1) or unexpected (section 2.2).

### 2.1 Graceful shutdown recovery

This is the orderly case. The host knows it is shutting down and can coordinate the transition.

#### Host (the process shutting down)

1. Signal handler (SIGTERM/SIGINT) fires, or `disconnectAsync()` is called
2. Host sends `HostTransferNotice` to all connected clients over their `/client` WebSockets
3. Host sends WebSocket close frame (code 1001, "Going Away") to all connected plugins
4. Host sends WebSocket close frame (code 1001) to all connected clients
5. Host closes the HTTP server, freeing port 38741
6. Host process exits

Steps 2-5 execute within a 2-second timeout. If any step takes longer (e.g., slow WebSocket close due to backpressure), the host force-closes remaining connections and exits anyway. The host MUST NOT hang indefinitely on shutdown.

```typescript
// Pseudocode for graceful shutdown in bridge-host.ts
async shutdownAsync(): Promise<void> {
  // Notify clients that host is going away
  for (const client of this._clients) {
    client.send(JSON.stringify({ type: 'host-transfer' }));
  }

  // Close all plugin WebSockets
  for (const session of this._sessionTracker.listAll()) {
    session.handle.close(1001, 'Host shutting down');
  }

  // Close all client WebSockets
  for (const client of this._clients) {
    client.close(1001, 'Host shutting down');
  }

  // Close the server (frees the port)
  await this._transportServer.closeAsync({ timeout: 2000 });
}
```

#### Client (receiving graceful shutdown notice)

1. Client receives `HostTransferNotice` message from the host
2. Client enters "takeover standby" -- it stops sending new requests and prepares to transition roles
3. Client receives WebSocket close frame from the host
4. Client attempts to bind port 38741 (no jitter needed -- the `HostTransferNotice` already primed it)
5. **If bind succeeds:** Client promotes to host role (see section 2.3)
6. **If bind fails (another client won the race):** Client waits 500ms, then connects as a client to the new host at `ws://localhost:38741/client`

```typescript
// Pseudocode for client-side graceful takeover in bridge-client.ts
private onHostTransferNotice(): void {
  this._takeoverPending = true;
  // Stop sending new requests; existing in-flight will timeout
}

private async onHostDisconnected(): Promise<void> {
  if (this._takeoverPending) {
    // Graceful: try immediately, no jitter
    await this.attemptTakeover();
  } else {
    // Crash: use jitter (section 2.2)
    await this.attemptTakeoverWithJitter();
  }
}
```

#### Plugin (receiving graceful close)

1. Plugin detects WebSocket close (code 1001)
2. If the last message received before close was `shutdown`, plugin transitions to `searching` (no backoff). NOTE: In the graceful path, the host sends a WebSocket close frame, not a `shutdown` protocol message. The plugin treats a clean close (code 1001) the same as receiving `shutdown` -- it transitions to `searching` without backoff.
3. Plugin begins polling `localhost:38741/health` every 2 seconds
4. When health returns 200, plugin opens a new WebSocket to `/plugin`
5. Plugin sends `session.register` with its persisted `instanceId`, its `context` (`edit`, `client`, or `server`), `placeId`, and `gameId`
6. New host responds with `welcome`, plugin enters `connected` state

The plugin does NOT know whether the new host is the same process or a different one. It does not need to know. The registration handshake is the same regardless.

### 2.2 Unexpected death recovery (hard kill, crash)

This is the disorderly case. No notifications were sent. Every participant discovers the failure independently through connection errors.

#### Client (detecting unexpected host death)

1. Client detects WebSocket `close` or `error` event on its `/client` connection
2. No `HostTransferNotice` was received -- client knows this was unexpected
3. Client waits a random jitter uniformly distributed in [0, 500ms] (to prevent thundering herd when multiple clients try to bind simultaneously)
4. Client attempts to bind port 38741
5. **If bind succeeds:** Client promotes to host role (see section 2.3)
6. **If bind fails with EADDRINUSE:**
   a. Another client may have won the race -- try connecting as a client to `ws://localhost:38741/client`
   b. If client connection succeeds -- done, operating as client to the new host
   c. If client connection fails -- the port may be in TIME_WAIT or held by a foreign process. Wait 1 second and retry from step 4. Retry up to 10 times (covering up to ~10 seconds of TIME_WAIT).
   d. After 10 retries, throw `HostUnreachableError`

```typescript
// Pseudocode for crash recovery in bridge-client.ts
private async attemptTakeoverWithJitter(): Promise<void> {
  // Random jitter to prevent thundering herd
  const jitterMs = Math.random() * 500;
  await delay(jitterMs);

  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      await this.tryBindPort(this._port);
      // Success: promote to host
      await this.promoteToHost();
      return;
    } catch (err) {
      if (err.code === 'EADDRINUSE') {
        // Try connecting as client (maybe another client took over)
        try {
          await this.connectAsClient(this._port);
          return; // Connected to new host
        } catch {
          // Port held but not by a bridge host. Wait and retry.
          await delay(1000);
        }
      } else {
        throw err;
      }
    }
  }

  throw new HostUnreachableError('localhost', this._port);
}
```

#### Plugin (detecting unexpected disconnect)

1. Plugin detects WebSocket `Closed` or `Error` event
2. No `shutdown` message preceded the close -- plugin transitions from `connected` to `reconnecting`
3. Plugin waits the current backoff duration (starts at 1 second)
4. Plugin transitions to `searching` and begins polling `localhost:38741/health`
5. If health returns 200, plugin connects and registers (same as section 2.1 step 4-6)
6. If health fails, plugin waits 2 seconds (poll interval) and retries
7. Backoff doubles on each failed reconnection cycle: 1s, 2s, 4s, 8s, 16s, 30s (capped)
8. Backoff resets to 0 on successful connection

### 2.3 Host takeover protocol

When a client successfully binds port 38741, it becomes the new bridge host. The takeover sequence is:

1. Client creates a new `TransportServer` and binds it to port 38741
2. Client starts the HTTP server (serves `/health` endpoint immediately)
3. Client initializes a new `SessionTracker` (empty -- no sessions yet)
4. Client sends `HostReadyNotice` to any remaining clients that were connected to the old host and are now connecting to this one
5. Client starts accepting plugin connections on `/plugin` and client connections on `/client`
6. Plugins discover the new host via health polling and send `register` messages
7. Each plugin registration creates a new `TrackedSession` in the `SessionTracker`
8. The new host emits `SessionEvent { event: 'connected' }` to all connected clients for each plugin that registers

**Critical detail:** The new host starts with an empty session map. It has no knowledge of which sessions existed on the old host. Session state is rebuilt entirely from plugin re-registrations. This means there is a window (typically 1-5 seconds) where `listSessions()` returns fewer sessions than actually exist -- some plugins have not yet reconnected.

The new host does NOT attempt to "import" or "restore" sessions from the old host. There is no state transfer between hosts. The session map is always derived from live WebSocket connections.

```typescript
// Pseudocode for host promotion in bridge-client.ts
private async promoteToHost(): Promise<void> {
  // Create and start the transport server
  this._host = new BridgeHost({ port: this._port });
  await this._host.startAsync();

  // Notify any clients that reconnect
  this._host.on('client-connection', (client) => {
    client.send(JSON.stringify({ type: 'host-ready' }));
  });

  // Update our own role
  this._role = 'host';

  debug('studio-bridge:failover')('Promoted to host on port %d', this._port);
}
```

### 2.4 No clients connected

When the host dies and there are no CLI clients connected:

1. Host exits, port is freed
2. Plugins detect the WebSocket close and enter `reconnecting` or `searching`
3. Plugins poll `localhost:38741/health`, get connection refused, continue polling with backoff
4. No automatic recovery is possible -- there is no client to take over the host role
5. The next CLI process to start (`studio-bridge exec`, `studio-bridge terminal`, etc.) calls `BridgeConnection.connectAsync()`, which binds port 38741 and becomes the new host
6. Plugins discover the new host on their next poll cycle and reconnect

This is the most common recovery scenario in practice: a developer runs a command, it finishes, the host exits (idle shutdown after 5 seconds), and the next command starts a fresh host. The plugins bridge the gap by polling.

## 3. State Recovery

### 3.1 What is lost

When the bridge host dies, the following state is irrecoverably lost:

| State | Location | Impact |
|-------|----------|--------|
| In-memory session map | `SessionTracker` in bridge-host.ts | New host starts with zero sessions until plugins re-register |
| Pending action requests | `PendingRequestMap` in bridge-host.ts | In-flight RPCs will never receive responses; clients must timeout |
| Client subscription map | Bridge host internal state | Clients must re-subscribe to session events after reconnecting |
| Log forwarding state | Bridge host push routing | Log streams (`followLogs()`) are interrupted; consumers must restart iteration |
| Host uptime counter | `HealthResponse.uptime` | Resets to 0 on the new host |

### 3.2 What survives

| State | Location | Why it survives |
|-------|----------|-----------------|
| Plugin `instanceId` | `plugin:SetSetting("StudioBridge_InstanceId")` | Persisted in Studio's plugin settings, survives everything except plugin uninstall |
| Plugin `context` | Determined at runtime from the DataModel environment (`edit`, `client`, or `server`) | Intrinsic to the plugin instance -- each context runs as a separate plugin instance |
| Plugin known ports | `plugin:SetSetting("StudioBridge_KnownPorts")` | Persisted in Studio's plugin settings |
| Session origin metadata | Plugin knows if it was `IS_EPHEMERAL` or persistent | Compiled into the plugin at build time |
| Studio's actual state | Roblox Studio process (unaffected by host death) | Studio is a separate process; host death does not crash Studio |
| Plugin log buffer | `LogBuffer` in plugin Luau code | The ring buffer continues accumulating entries during disconnection |
| Plugin state monitor | `StateMonitor` in plugin Luau code | Tracks Studio state changes while disconnected; can push delta on reconnect |

### 3.3 What is recovered

| State | How recovered | Timeline |
|-------|---------------|----------|
| Sessions | Plugins re-register with the new host, sending `instanceId`, `context`, `placeId`, `gameId`, place name, capabilities, and current state. A Studio instance in Play mode re-registers 3 sessions (edit, client, server contexts). | 1-5 seconds after new host is available |
| Session IDs | Each plugin generates a fresh UUID as its proposed session ID when re-registering; the new host accepts or overrides it. `(instanceId, context)` provides continuity for correlation. | Immediate on registration |
| Instance grouping | Sessions sharing the same `instanceId` are re-grouped automatically as each context re-registers. During recovery, the group may be partially populated (e.g., 1 of 3 contexts reconnected). | Progressive, complete within 5 seconds |
| Log history | Queried from the plugin's `LogBuffer` on demand (buffered entries survive the gap) | Available immediately after session re-registration |
| Studio state | Included in the plugin's `register` message | Available immediately after session re-registration |
| Client session list | Rebuilt from `SessionEvent` messages as plugins reconnect | Progressive, complete within 5 seconds |

### 3.4 Instance ID and context continuity

The `(instanceId, context)` pair is the unique key for correlating sessions across host failures. A single `instanceId` can have up to 3 sessions when Studio is in Play mode (one each for `edit`, `client`, and `server` contexts). When a plugin reconnects to a new host:

- The plugin generates a fresh UUID as its proposed `sessionId` (via `HttpService:GenerateGUID()`), which the new host accepts or overrides in the `welcome` response. The new host has no memory of the old host's session IDs.
- The plugin sends the same `instanceId` and `context` it has always used, along with `placeId` and `gameId`
- Observability tools and logs can match pre-failure and post-failure sessions by `(instanceId, context)`
- A Studio instance in Play mode produces 3 re-registrations during failover -- one per context. These arrive independently (possibly seconds apart) and are grouped by `instanceId`
- Consumer code that cached a `sessionId` will find it invalid after failover; it must re-resolve sessions via `BridgeConnection.listSessions()` or `waitForSession()`

This design means that session IDs are ephemeral (scoped to a single host lifetime) while instance IDs are durable (scoped to a plugin installation). The `context` field is determined by which DataModel environment the plugin instance is running in. Consumer code should NOT persist session IDs across process restarts.

**Recovery example -- Studio in Play mode**: Before failover, one Studio instance had 3 sessions (edit/client/server) all sharing `instanceId: "abc-123"`. After the host dies and a new host starts:

| Re-registration order | instanceId | context | New sessionId | Group complete? |
|----------------------|------------|---------|---------------|-----------------|
| 1st (arrives at T+2s) | abc-123 | edit | new-001 | 1 of 3 |
| 2nd (arrives at T+2.5s) | abc-123 | server | new-002 | 2 of 3 |
| 3rd (arrives at T+3s) | abc-123 | client | new-003 | 3 of 3 |

During the recovery window, `listSessions()` may return a partially-populated instance group. Consumers that need all 3 contexts should wait until the group is complete or use a short grace period after the first session in a group appears.

## 4. Graceful Shutdown Protocol

This section provides the detailed timeline for a graceful shutdown, which is the best-case scenario for host transitions.

### 4.1 Signal handling

The bridge host registers handlers for SIGTERM and SIGINT:

```typescript
// In bridge-host.ts startup
process.on('SIGTERM', () => this.shutdownAsync());
process.on('SIGINT', () => this.shutdownAsync());
```

The shutdown handler is idempotent -- calling it multiple times (e.g., user presses Ctrl+C twice) does not cause errors. The second call is a no-op if shutdown is already in progress.

### 4.2 Shutdown sequence timeline

```
T+0ms     Signal received. Host begins shutdown.
T+0ms     Host sends HostTransferNotice to all clients.
T+10ms    Host sends WebSocket close (1001) to all plugins.
T+20ms    Host sends WebSocket close (1001) to all clients.
T+30ms    Host calls server.close(), beginning port release.
T+50ms    Port is freed. Host process exits.

T+50ms    First client detects close, attempts to bind port.
T+100ms   Client successfully binds port, starts new host.
T+100ms   New host serves /health endpoint.

T+2000ms  Plugin polls /health, gets 200.
T+2100ms  Plugin opens WebSocket, sends register.
T+2200ms  New host creates session, sends welcome.
T+2200ms  Recovery complete for this plugin.
```

Total time from signal to full recovery: approximately 2 seconds (dominated by the plugin's 2-second poll interval).

### 4.3 Shutdown timeout

If any step in the shutdown sequence blocks for more than 2 seconds (e.g., a WebSocket close handshake hangs because the remote end is unresponsive), the host force-terminates all connections:

```typescript
private async shutdownAsync(): Promise<void> {
  if (this._shuttingDown) return;
  this._shuttingDown = true;

  const shutdownTimer = setTimeout(() => {
    debug('studio-bridge:host')('Shutdown timeout, force-closing');
    this._transportServer.forceClose();
    process.exit(0);
  }, 2000);

  try {
    await this.gracefulShutdown();
  } finally {
    clearTimeout(shutdownTimer);
  }

  process.exit(0);
}
```

### 4.4 Drain behavior

When a client receives `HostTransferNotice`, it enters drain mode:

1. **Stop sending new requests:** Any calls to `session.execAsync()` or other action methods while in drain mode queue internally rather than sending to the dying host.
2. **Wait for in-flight responses:** Existing pending requests have two possible outcomes:
   a. The host responds before closing -- the response is delivered normally.
   b. The host closes before responding -- the pending request rejects with `SessionDisconnectedError`.
3. **Transition:** Once the host's WebSocket close frame arrives, the client proceeds to takeover (section 2.3).

The drain window is brief (typically under 50ms between `HostTransferNotice` and WebSocket close). In-flight requests during this window almost always fail. Consumer code should be prepared to retry.

## 5. Edge Cases and Race Conditions

### 5.1 Two clients try to become host simultaneously

**Scenario:** The host dies with two clients connected. Both detect the disconnect and attempt to bind port 38741.

**Resolution:** The OS guarantees that `bind()` is atomic. Exactly one client will succeed; the other gets EADDRINUSE. The losing client then connects as a client to the winning one.

**Jitter mitigation:** Each client waits a random 0-500ms delay before attempting to bind (in the crash case only; graceful shutdown does not use jitter). This reduces contention and makes the race less likely, but does not eliminate it -- and does not need to. The bind-or-connect fallback is correct regardless of timing.

**Sequence diagram:**
```
Host dies (crash)
     |
     +-- Client A: waits 150ms jitter, tries bind → SUCCESS → becomes host
     |
     +-- Client B: waits 300ms jitter, tries bind → EADDRINUSE
                   tries connect to :38741/client → SUCCESS → becomes client
```

### 5.2 Plugin reconnects before any client becomes host

**Scenario:** The host dies. A plugin enters `reconnecting`, waits 1 second (initial backoff), transitions to `searching`, and polls `/health`. No client has taken over the port yet.

**What happens:** The health check gets connection refused. The plugin stays in `searching`, polls again in 2 seconds. This repeats until a client binds the port or a new CLI process starts.

**No harm done:** The plugin is designed to poll indefinitely. Each failed health check is a lightweight HTTP GET that returns immediately with connection refused. There is no timeout or retry limit on discovery.

### 5.3 TIME_WAIT prevents port rebind

**Scenario:** The host crashes while actively sending data. The OS places the socket in TIME_WAIT. A client tries to bind the port.

**With SO_REUSEADDR (required by spec):** The bind succeeds despite TIME_WAIT. This is the expected path.

**Without SO_REUSEADDR (should never happen):** The bind fails with EADDRINUSE. The client's retry loop (section 2.2, step 6) retries every 1 second for up to 10 attempts. TIME_WAIT typically resolves within this window on macOS (15-30 seconds) but may exceed it on Linux (60 seconds).

**Verification:** The transport server MUST log a warning at startup if `SO_REUSEADDR` is not set. This is a defense-in-depth check; Node.js `http.Server` sets it by default.

### 5.4 Host dies mid-action

**Scenario:** A client has sent a `HostEnvelope` with an action (e.g., `execute`) to the host. The host forwarded it to the plugin. The host crashes before the plugin's response can be relayed back.

**What the client observes:**
1. The WebSocket to the host closes unexpectedly
2. The pending request in the client's `PendingRequestMap` has no response
3. The client enters the takeover flow (section 2.2)
4. Meanwhile, the pending request's timeout timer continues ticking

**Resolution:** The pending request eventually times out (default 30 seconds, configurable per action type). The consumer receives `ActionTimeoutError`. The consumer must decide whether to retry.

**What happened on the plugin side:** The plugin may have already executed the script. The response was sent to the (now-dead) host. When the plugin reconnects to the new host, the old response is not resent -- it was a response to a request on the old host's connection, and the new host has no knowledge of it. This means the action may have had side effects (e.g., the script modified Studio state) without the consumer knowing it succeeded.

**Mitigation for consumers:** Actions that have side effects should be idempotent where possible. The `execute` action cannot be made automatically idempotent (arbitrary Luau code), so consumers of `execAsync()` must handle `ActionTimeoutError` as "unknown outcome" and decide whether to retry.

### 5.5 Rapid kill+restart cycle

**Scenario:** User presses Ctrl+C on the host process and immediately runs `studio-bridge exec 'print("hello")'`. The new CLI process starts within milliseconds of the old one dying.

**What happens:**
1. Old host begins graceful shutdown (section 4)
2. New CLI process starts, calls `BridgeConnection.connectAsync()`
3. `connectAsync()` tries to bind port 38741
4. If the old host has not yet released the port: EADDRINUSE. The new process tries to connect as a client.
5. The client connection attempt may succeed briefly (the old host is still alive) or fail (the old host has closed its server socket)
6. If the client connection fails, the new process retries the bind (up to 3 retries at 1-second intervals per `07-bridge-network.md` section 4.1)
7. By the time retries start, the old host has finished shutting down and freed the port
8. The new process binds the port and becomes the host

**Timeline:** The new process becomes the host within 1-2 seconds of starting. This covers the overlap window where the old host is still shutting down.

### 5.6 All clients die, only plugins remain

**Scenario:** The bridge host was an implicit host (a CLI process). It exits. There are no other CLI clients. Multiple Studio instances with persistent plugins are still running.

**What happens:**
1. Plugins detect WebSocket close, enter `reconnecting` or `searching`
2. Plugins poll `/health` with backoff
3. No process binds port 38741
4. Plugins poll indefinitely (no timeout, no retry limit)
5. Eventually, a user runs a CLI command. The new process binds port 38741, becomes the host.
6. Plugins discover the new host on their next poll cycle, connect, and register.

**Design note:** The plugins are designed to be patient. They will poll for hours, days, or weeks without ill effect. The polling interval is 2 seconds during active searching, which is lightweight (a single HTTP GET that returns connection refused). There is no exponential backoff on the discovery poll itself -- only on reconnection after a connection that was previously established drops.

### 5.7 Managed session with dead host

**Scenario:** The bridge host launched Studio with `origin: 'managed'`. The host dies. Should Studio be killed?

**Answer: No.** The host that dies cannot kill Studio (it is dead). The new host, when it sees the plugin reconnect, observes that the session's `origin` is reported by the plugin. Managed vs. user origin is a property of how the session was originally established. The new host does not kill managed sessions just because it was not the host that launched them.

However, managed session cleanup semantics still apply: when the new host shuts down gracefully, it may choose to close managed sessions (this depends on the `keepAlive` option and idle shutdown logic, per `07-bridge-network.md` section 6.5). The reconnected session inherits its origin classification.

### 5.8 Client has stale session references after failover

**Scenario:** A consumer holds a `BridgeSession` reference from before the failover. After failover, the consumer tries to use it.

**What happens:** The old `BridgeSession` holds a `TransportHandle` that is disconnected. Any action method called on it rejects with `SessionDisconnectedError`.

**Recovery:** The consumer must re-resolve sessions from `BridgeConnection`:
```typescript
// Before failover
const session = await bridge.waitForSession();
await session.execAsync('print("hello")'); // works

// Host dies, client takes over, plugin reconnects

await session.execAsync('print("hello")'); // throws SessionDisconnectedError

// Recovery: get the new session
const newSession = await bridge.waitForSession();
await newSession.execAsync('print("hello")'); // works
```

`BridgeConnection` emits `'session-disconnected'` and then `'session-connected'` events during failover. Consumer code that listens to these events can update its session references automatically.

### 5.9 Multiple host deaths in rapid succession

**Scenario:** Host A dies. Client B takes over as host. Client B immediately dies (e.g., the user is rapidly Ctrl+C-ing all terminals).

**What happens:** Client C (if it exists) detects Client B's death and attempts takeover. The recovery protocol is the same regardless of how many times it has been invoked. Each client independently follows the same logic: detect disconnect, jitter, try bind, fallback to client.

If all clients die, only plugins remain (section 5.6). The system degrades gracefully to "plugins polling, waiting for any host."

### 5.10 Failover during `studio-bridge serve`

**Scenario:** A dedicated host started via `studio-bridge serve` crashes. There are CLI clients connected.

**What happens:** Same as any other host crash (section 2.2). A connected client takes over. The difference is that `serve` was running with `keepAlive: true`, meaning the host was intended to be long-lived. The client that takes over may or may not have `keepAlive: true`.

**Recommendation:** If the user is running `serve` for a reason (e.g., devcontainer support), they should restart `serve` after the crash. The client that temporarily took over will detect the new `serve` instance and relinquish the host role (by disconnecting and reconnecting as a client when it detects the dedicated host).

Actually, there is no "relinquish" mechanism in the current design. Once a client becomes a host, it stays a host until it exits. The user must manually stop the temporary host and restart `serve`. This is an acceptable limitation for an edge case (dedicated host crashing), and adding a relinquish protocol would add significant complexity for minimal benefit.

## 6. Observability

### 6.1 Plugin output messages

The plugin logs all connection state transitions to Studio's Output window with a `[StudioBridge]` prefix. These messages are the primary debugging tool for plugin-side issues.

| State transition | Output message |
|-----------------|----------------|
| Plugin starts, enters discovery | `[StudioBridge] Persistent mode, searching for server...` |
| Health check succeeds | `[StudioBridge] searching -> connecting` |
| WebSocket opened, handshake complete | `[StudioBridge] connecting -> connected` or `[StudioBridge] Connected (v2)` |
| WebSocket closed unexpectedly | `[StudioBridge] connected -> reconnecting` |
| Clean shutdown received | `[StudioBridge] connected -> searching` |
| Backoff timer expires | `[StudioBridge] reconnecting -> searching` |
| Reconnection to new host succeeds | `[StudioBridge] Reconnected (new host)` |

The "Reconnected (new host)" message is emitted when the plugin connects and the health response shows a different `uptime` value (near zero, indicating a fresh host) compared to the previous connection. This helps distinguish "reconnected to the same host after a blip" from "connected to a new host after failover."

### 6.2 CLI output messages

CLI commands that encounter host failure show clear, actionable messages:

| Scenario | CLI output |
|----------|-----------|
| Host unreachable during `connectAsync()` | `Bridge host unreachable on port 38741. Attempting to become host...` |
| Client successfully takes over | `Promoted to bridge host on port 38741.` |
| Client connects to new host after takeover | `Connected to bridge host on port 38741 (new host).` |
| Action timeout after host death | `Error: Action timed out after 30000ms. The bridge host may have crashed during execution.` |
| All retries exhausted | `Error: Unable to connect to bridge host on port 38741 after 10 attempts. Is another process using this port?` |
| Recovery in progress | `Waiting for bridge host... (attempt 3/10)` |

### 6.3 `studio-bridge sessions` during recovery

The `sessions` command reflects the live state of the session tracker, which means it shows the recovery in progress:

```
$ studio-bridge sessions
No active sessions. (Host started 2s ago, waiting for plugins to reconnect.)
```

If the host has been up for less than 10 seconds and has zero sessions, the output includes the "(waiting for plugins to reconnect)" hint. After 10 seconds with no sessions, the hint changes to standard "no sessions" output.

When sessions are reconnecting progressively:
```
$ studio-bridge sessions
SESSION ID    PLACE NAME       CONTEXT   STATE   CONNECTED
abc-123       MyGame           edit      Edit    2s ago
abc-124       MyGame           server    Play    2s ago

(2 sessions connected across 1 instance. More plugins may still be reconnecting.)
```

A Studio instance in Play mode may show partial recovery -- for example, the `edit` and `server` contexts may reconnect before the `client` context.

The "more plugins may still be reconnecting" hint appears when the host has been up for less than 10 seconds.

### 6.4 Health endpoint during failover

| Host state | Health endpoint behavior |
|-----------|-------------------------|
| Host alive and healthy | `200 OK` with JSON body |
| Host shutting down (graceful) | Connection may succeed or fail depending on timing |
| Host dead | Connection refused (ECONNREFUSED) |
| New host starting | `200 OK` with `uptime: 0` (or very low), `sessions: 0` |
| New host with reconnected plugins | `200 OK` with accurate session count |

### 6.5 Debug logging

When `DEBUG=studio-bridge:*` is set (or the equivalent verbose flag), the bridge logs every state transition in the failover process:

```
studio-bridge:host Shutdown signal received (SIGTERM)
studio-bridge:host Sending HostTransferNotice to 2 clients
studio-bridge:host Closing 3 plugin connections
studio-bridge:host Closing 2 client connections
studio-bridge:host Server closed, port 38741 released
studio-bridge:client Host disconnected (HostTransferNotice received)
studio-bridge:client Attempting takeover of port 38741
studio-bridge:client Bind succeeded, promoting to host
studio-bridge:failover Promoted to host on port 38741
studio-bridge:host Plugin connected: instanceId=abc-123, context=edit
studio-bridge:host Session registered: sessionId=new-456, instanceId=abc-123, context=edit, placeName=MyGame
studio-bridge:host Plugin connected: instanceId=abc-123, context=server
studio-bridge:host Session registered: sessionId=new-457, instanceId=abc-123, context=server, placeName=MyGame
studio-bridge:host Plugin connected: instanceId=abc-123, context=client
studio-bridge:host Session registered: sessionId=new-458, instanceId=abc-123, context=client, placeName=MyGame
studio-bridge:host Plugin connected: instanceId=def-789, context=edit
studio-bridge:host Session registered: sessionId=new-012, instanceId=def-789, context=edit, placeName=TestPlace
```

The `studio-bridge:failover` debug namespace is specifically for failover-related events, making it easy to filter for failover diagnostics:

```
DEBUG=studio-bridge:failover studio-bridge exec 'print("hello")'
```

### 6.6 Error types for failover scenarios

All failover-related errors use the typed error classes from `07-bridge-network.md` section 2.7:

| Error class | When thrown during failover |
|-------------|---------------------------|
| `HostUnreachableError` | All takeover retries exhausted; port held by foreign process |
| `ActionTimeoutError` | In-flight action lost due to host death; timeout expired |
| `SessionDisconnectedError` | Consumer tries to use a session from the old host |
| `HandOffFailedError` | Graceful hand-off initiated but no client could take over |

## 7. Testing Strategy

### 7.1 Unit tests

Unit tests validate individual components of the failover system in isolation.

#### State machine transitions (bridge-client.ts)

Test that the client correctly transitions through failover states:

```typescript
describe('bridge-client failover', () => {
  it('enters takeover mode on HostTransferNotice', () => {
    const client = createBridgeClient({ port: TEST_PORT });
    simulateMessage(client, { type: 'host-transfer' });
    expect(client.state).toBe('takeover-standby');
  });

  it('enters takeover mode on unexpected disconnect', () => {
    const client = createBridgeClient({ port: TEST_PORT });
    await client.connectAsync();
    simulateDisconnect(client);
    expect(client.state).toBe('takeover-attempt');
  });

  it('rejects pending requests on host death', async () => {
    const client = createBridgeClient({ port: TEST_PORT });
    const pending = client.sendActionAsync({ type: 'execute', ... }, 5000);
    simulateDisconnect(client);
    await expect(pending).rejects.toThrow(SessionDisconnectedError);
  });
});
```

#### Jitter distribution (hand-off.ts)

Test that the jitter delay is within the expected range and uniformly distributed:

```typescript
describe('takeover jitter', () => {
  it('produces delays between 0 and 500ms', () => {
    const delays = Array.from({ length: 1000 }, () => computeTakeoverJitter());
    expect(Math.min(...delays)).toBeGreaterThanOrEqual(0);
    expect(Math.max(...delays)).toBeLessThanOrEqual(500);
  });

  it('skips jitter for graceful shutdown', () => {
    const delay = computeTakeoverJitter({ graceful: true });
    expect(delay).toBe(0);
  });
});
```

#### Session tracker reset (session-tracker.ts)

Test that a new session tracker starts empty and rebuilds from registrations:

```typescript
describe('session tracker after failover', () => {
  it('starts with zero sessions', () => {
    const tracker = new SessionTracker();
    expect(tracker.listSessions()).toEqual([]);
  });

  it('adds sessions from register messages', () => {
    const tracker = new SessionTracker();
    tracker.addSession('s1', mockSessionInfo({ instanceId: 'inst-1', context: 'edit' }), mockHandle());
    expect(tracker.listSessions()).toHaveLength(1);
    expect(tracker.listSessions()[0].sessionId).toBe('s1');
  });

  it('groups sessions by instanceId across contexts', () => {
    const tracker = new SessionTracker();
    tracker.addSession('s1', mockSessionInfo({ instanceId: 'inst-1', context: 'edit' }), mockHandle());
    tracker.addSession('s2', mockSessionInfo({ instanceId: 'inst-1', context: 'server' }), mockHandle());
    tracker.addSession('s3', mockSessionInfo({ instanceId: 'inst-1', context: 'client' }), mockHandle());
    expect(tracker.listSessions()).toHaveLength(3);
    // All three sessions share the same instanceId but have different contexts
    const contexts = tracker.listSessions().map(s => s.context).sort();
    expect(contexts).toEqual(['client', 'edit', 'server']);
  });
});
```

### 7.2 Integration tests

Integration tests exercise the full failover path with mock plugins and real WebSocket connections.

#### Graceful shutdown + client takeover

```typescript
it('client takes over after graceful host shutdown', async () => {
  // Start host on ephemeral port
  const host = await createTestHost({ port: 0 });
  const port = host.port;

  // Connect a mock plugin (edit context)
  const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
  await plugin.connectAsync();
  await plugin.waitForWelcome();

  // Connect a client
  const client = await BridgeConnection.connectAsync({ port });
  expect(client.role).toBe('client');

  // Verify session exists
  const sessions = client.listSessions();
  expect(sessions).toHaveLength(1);

  // Shut down the host gracefully
  await host.shutdownAsync();

  // Wait for client to take over
  await waitForCondition(() => client.role === 'host', 5000);
  expect(client.role).toBe('host');

  // Wait for plugin to reconnect
  await plugin.waitForReconnection(5000);

  // Verify session is restored
  const newSessions = client.listSessions();
  expect(newSessions).toHaveLength(1);
  // Session ID may differ, but (instanceId, context) is the same
});
```

#### Hard kill + client takeover

```typescript
it('client takes over after host crash', async () => {
  const host = await createTestHost({ port: 0 });
  const port = host.port;

  const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
  await plugin.connectAsync();
  await plugin.waitForWelcome();

  const client = await BridgeConnection.connectAsync({ port });
  expect(client.role).toBe('client');

  // Kill the host without graceful shutdown
  host.forceClose(); // closes server socket immediately, no notifications

  // Wait for client to take over
  await waitForCondition(() => client.role === 'host', 5000);

  // Wait for plugin to reconnect
  await plugin.waitForReconnection(10000);

  // Verify actions work through the new host
  plugin.onAction('queryState', () => ({
    type: 'stateResult',
    payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 }
  }));

  const session = await client.waitForSession(5000);
  const state = await session.queryStateAsync();
  expect(state.state).toBe('Edit');
});
```

#### No clients -- plugin waits for new host

```typescript
it('plugin reconnects when new host appears after gap', async () => {
  const host = await createTestHost({ port: 0 });
  const port = host.port;

  const plugin = createMockPlugin({ port, instanceId: 'inst-1', context: 'edit' });
  await plugin.connectAsync();
  await plugin.waitForWelcome();

  // Kill host with no clients
  host.forceClose();

  // Plugin enters reconnecting/searching
  await waitForCondition(() => plugin.state === 'searching', 5000);

  // Start a new host on the same port
  const newHost = await createTestHost({ port });

  // Wait for plugin to discover and reconnect
  await plugin.waitForReconnection(10000);

  // Verify the new host has the session
  expect(newHost.listSessions()).toHaveLength(1);
});
```

#### Two clients race for host

```typescript
it('exactly one client becomes host when two race', async () => {
  const host = await createTestHost({ port: 0 });
  const port = host.port;

  const clientA = await BridgeConnection.connectAsync({ port });
  const clientB = await BridgeConnection.connectAsync({ port });

  // Kill the host
  host.forceClose();

  // Wait for both clients to settle
  await waitForCondition(
    () => clientA.isConnected && clientB.isConnected,
    10000
  );

  // Exactly one should be host, the other should be client
  const roles = [clientA.role, clientB.role].sort();
  expect(roles).toEqual(['client', 'host']);
});
```

### 7.3 Mock plugin reconnection support

The `createMockPlugin()` helper from `07-bridge-network.md` section 8.1 is extended with reconnection behavior for failover testing:

```typescript
interface MockPlugin {
  // ... existing methods from 07-bridge-network.md ...

  /** Current connection state. */
  readonly state: 'disconnected' | 'connecting' | 'connected' | 'searching';

  /**
   * Wait for the plugin to reconnect after a disconnection.
   * Simulates the persistent plugin's reconnection behavior:
   * detects disconnect, polls health, reconnects, re-registers.
   */
  waitForReconnection(timeoutMs: number): Promise<void>;

  /**
   * Enable auto-reconnection behavior.
   * When enabled, the mock plugin polls the health endpoint
   * and reconnects automatically, just like the real plugin.
   */
  enableAutoReconnect(options?: {
    pollIntervalMs?: number;  // default: 500 (faster than real plugin for tests)
    backoffMs?: number;       // default: 100 (faster for tests)
  }): void;
}

function createMockPlugin(options?: MockPluginOptions): MockPlugin;

interface MockPluginOptions {
  port?: number;
  instanceId?: string;
  context?: SessionContext;  // 'edit' | 'client' | 'server', default: 'edit'
  placeName?: string;
  placeId?: number;
  gameId?: number;
  capabilities?: Capability[];
  protocolVersion?: number;
  autoReconnect?: boolean; // default: true for failover tests
}
```

The mock plugin's reconnection uses shorter intervals than the real plugin (500ms poll, 100ms backoff) to keep tests fast. The real plugin uses 2-second polls and 1-30 second backoff.

### 7.4 Chaos testing guidance

These scenarios cannot be fully automated in unit/integration tests and should be tested manually or in a staging environment:

**Rapid kill cycle:**
1. Start `studio-bridge serve`
2. Open 3 Studio instances, verify all sessions appear in `studio-bridge sessions`
3. Put one Studio instance into Play mode (this creates 3 sessions: edit, client, server)
4. Kill the serve process (kill -9)
5. Immediately run `studio-bridge sessions`
6. Verify the new process becomes host and all sessions reconnect within 5 seconds (including all 3 contexts for the Play-mode instance)

**Multi-client takeover race:**
1. Start `studio-bridge serve` (the host)
2. Open a terminal and run `studio-bridge terminal` (client A)
3. Open another terminal and run `studio-bridge terminal` (client B)
4. Kill the serve process (kill -9)
5. Verify that exactly one terminal becomes host, the other remains a client
6. Verify both terminals can still execute commands

**TIME_WAIT recovery:**
1. Start a host process
2. Connect a plugin and send a large action (e.g., execute a script that generates megabytes of output)
3. Kill the host mid-transfer (kill -9)
4. Immediately start a new host on the same port
5. Verify the new host can bind (SO_REUSEADDR handles TIME_WAIT)

**Sustained disconnection:**
1. Start a host process
2. Connect a Studio instance with the persistent plugin
3. Kill the host process
4. Wait 5 minutes (no host running)
5. Start a new host
6. Verify the plugin reconnects (it should still be polling)

**OOM simulation:**
1. Start a host process with a low memory limit (`NODE_OPTIONS="--max-old-space-size=64"`)
2. Send actions that allocate memory (large script outputs, screenshots)
3. Observe the OOM crash and verify client takeover works

## 8. Timeline Guarantees

These are the expected recovery times for each failure scenario. They assume standard conditions: localhost networking, modern hardware, no unusual OS load, `SO_REUSEADDR` enabled.

| Scenario | Expected Recovery Time | Limiting Factor |
|----------|----------------------|-----------------|
| Graceful shutdown + client takeover | < 2 seconds | Plugin poll interval (2s) |
| Graceful shutdown + no clients + new CLI command | < 3 seconds | Plugin poll interval + CLI startup |
| Hard kill + client takeover | < 5 seconds | Jitter (0-500ms) + plugin backoff (1s) + poll interval (2s) |
| Hard kill + no clients + new CLI command | < 3 seconds | CLI startup time + plugin poll interval |
| TIME_WAIT port recovery (with SO_REUSEADDR) | < 1 second | Kernel socket teardown |
| TIME_WAIT port recovery (without SO_REUSEADDR) | < 60 seconds | TCP TIME_WAIT timer (Linux) |
| Plugin reconnection after new host available | < 5 seconds | Backoff position + poll interval |
| Port conflict resolution (foreign process) | Indefinite | Depends on external process |
| Consumer session re-resolution after failover | < 1 second | `waitForSession()` resolves immediately if a session is already connected |

### 8.1 What these guarantees do NOT cover

- **Studio startup time:** If the host dies and Studio is not running, starting Studio takes 10-30 seconds. This is outside the scope of failover recovery (the failover is about reconnecting existing Studio instances, not launching new ones).
- **Plugin installation:** If the persistent plugin is not installed, the failover recovery path is not available. Ephemeral plugins do not reconnect.
- **Network issues beyond localhost:** In split-server mode, network failures between the devcontainer and the host OS are not covered by this spec. The devcontainer sees a disconnection and follows the same client recovery path, but the recovery time depends on the port-forwarding infrastructure.
- **OS-level failures:** Kernel panics, disk full, or system-wide resource exhaustion are outside the scope of application-level recovery.

## 9. Implementation Notes

### 9.1 SO_REUSEADDR requirement

The transport server MUST create its HTTP server with `SO_REUSEADDR`. In Node.js:

```typescript
const server = http.createServer();
// Node.js sets SO_REUSEADDR by default on server.listen().
// This comment exists to prevent future refactors from using
// a custom socket creation path that might omit it.
server.listen(port, 'localhost');
```

If the implementation ever moves to a raw `net.Server` or a third-party HTTP library, `SO_REUSEADDR` must be explicitly set:

```typescript
const server = net.createServer();
server.on('listening', () => {
  // Verify SO_REUSEADDR is set (defense in depth)
  // Node.js does this automatically, but log a warning if not
});
```

### 9.2 Shutdown handler registration

The bridge host MUST register shutdown handlers early in its lifecycle, before any async work:

```typescript
class BridgeHost {
  async startAsync(): Promise<void> {
    // Register signal handlers FIRST, before binding port
    this.registerShutdownHandlers();

    // Now do the potentially-slow work
    await this._transportServer.listenAsync(this._port);
  }

  private registerShutdownHandlers(): void {
    const shutdown = () => this.shutdownAsync();
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);

    // Also handle uncaught exceptions for best-effort notification
    process.on('uncaughtException', (err) => {
      debug('studio-bridge:host')('Uncaught exception: %O', err);
      // Best-effort: try to notify clients, but don't block on it
      this.shutdownAsync().catch(() => {}).finally(() => process.exit(1));
    });
  }
}
```

### 9.3 Idempotent shutdown

The shutdown handler MUST be idempotent. Users may press Ctrl+C multiple times, or SIGTERM may arrive while a previous shutdown is in progress:

```typescript
private _shuttingDown = false;

async shutdownAsync(): Promise<void> {
  if (this._shuttingDown) {
    debug('studio-bridge:host')('Shutdown already in progress, ignoring');
    return;
  }
  this._shuttingDown = true;
  // ... shutdown logic ...
}
```

### 9.4 Pending request cleanup on failover

When a client transitions from client role to host role, it must reject all pending requests from the old connection:

```typescript
private async promoteToHost(): Promise<void> {
  // Reject all pending requests from the client connection
  this._pendingRequests.rejectAll(
    new SessionDisconnectedError('Host died during request')
  );

  // Clear the pending request map
  this._pendingRequests.clear();

  // Now set up the host
  // ...
}
```

### 9.5 File layout for failover code

The failover logic lives in existing files from the `07-bridge-network.md` file layout. No new files are needed:

| File | Failover responsibility |
|------|------------------------|
| `src/bridge/internal/hand-off.ts` | Takeover logic (jitter, bind, promote), graceful shutdown coordination |
| `src/bridge/internal/bridge-host.ts` | Shutdown handler, `HostTransferNotice` sending, connection close sequencing |
| `src/bridge/internal/bridge-client.ts` | Disconnect detection, takeover decision (graceful vs. crash), role transition |
| `src/bridge/internal/transport-server.ts` | `SO_REUSEADDR` configuration, `forceClose()` method |
| `src/bridge/internal/transport-client.ts` | Reconnection backoff, disconnect event propagation |
| `src/bridge/internal/session-tracker.ts` | Reset/rebuild on new host, `(instanceId, context)`-based session correlation, instance grouping |
