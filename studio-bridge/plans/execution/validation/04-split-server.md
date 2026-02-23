# Validation: Phase 4 -- Split Server Mode

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Test specifications for split server (daemon) mode: serve command, remote client, devcontainer auto-detection.

**Phase**: 4 (Split Server / Devcontainer Support)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/04-split-server.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/04-split-server.md`
- Tech spec: `studio-bridge/plans/tech-specs/05-split-server.md`
- Sibling validation: `01-bridge-network.md` (Phase 1), `02-plugin.md` (Phase 2), `03-commands.md` (Phase 3)

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 1. Unit Test Plans

### 1.1 Serve Command Handler

Tests for `src/commands/serve.ts`.

---

- **Test name**: `serveAsync calls BridgeConnection.connectAsync with keepAlive: true`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `BridgeConnection.connectAsync` to return a mock connection object.
- **Steps**:
  1. Call `serveAsync({})`.
  2. Verify `BridgeConnection.connectAsync` was called with `{ keepAlive: true, port: 38741 }`.
- **Expected result**: `connectAsync` receives `keepAlive: true`.
- **Automation**: vitest with mock.

---

- **Test name**: `serveAsync passes custom port to connectAsync`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `BridgeConnection.connectAsync`.
- **Steps**:
  1. Call `serveAsync({ port: 39000 })`.
  2. Verify `connectAsync` was called with `port: 39000`.
- **Expected result**: Custom port is forwarded.
- **Automation**: vitest with mock.

---

- **Test name**: `serveAsync throws clear error on EADDRINUSE`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `BridgeConnection.connectAsync` to throw an error with `code: 'EADDRINUSE'`.
- **Steps**:
  1. Call `serveAsync({ port: 38741 })`.
- **Expected result**: Rejects with error message containing "already in use" and "--port".
- **Automation**: vitest with mock.

---

### 1.2 Environment Detection

Tests for `src/bridge/internal/environment-detection.ts`.

---

- **Test name**: `isDevcontainer returns true when REMOTE_CONTAINERS is set`
- **Priority**: P0
- **Type**: unit
- **Setup**: Set `process.env.REMOTE_CONTAINERS = 'true'`.
- **Steps**:
  1. Call `isDevcontainer()`.
- **Expected result**: Returns `true`.
- **Automation**: vitest.

---

- **Test name**: `isDevcontainer returns true when CODESPACES is set`
- **Priority**: P0
- **Type**: unit
- **Setup**: Set `process.env.CODESPACES = 'true'`.
- **Steps**:
  1. Call `isDevcontainer()`.
- **Expected result**: Returns `true`.
- **Automation**: vitest.

---

- **Test name**: `isDevcontainer returns true when CONTAINER is set`
- **Priority**: P0
- **Type**: unit
- **Setup**: Set `process.env.CONTAINER = 'podman'`.
- **Steps**:
  1. Call `isDevcontainer()`.
- **Expected result**: Returns `true`.
- **Automation**: vitest.

---

- **Test name**: `isDevcontainer returns false when no signals are present`
- **Priority**: P0
- **Type**: unit
- **Setup**: Clear all detection env vars, mock `existsSync('/.dockerenv')` to return false.
- **Steps**:
  1. Call `isDevcontainer()`.
- **Expected result**: Returns `false`.
- **Automation**: vitest.

---

- **Test name**: `isDevcontainer treats empty string env var as falsy`
- **Priority**: P1
- **Type**: unit
- **Setup**: Set `process.env.REMOTE_CONTAINERS = ''`.
- **Steps**:
  1. Call `isDevcontainer()`.
- **Expected result**: Returns `false`.
- **Automation**: vitest.

---

- **Test name**: `getDefaultRemoteHost returns localhost:38741 in devcontainer`
- **Priority**: P0
- **Type**: unit
- **Setup**: Set `process.env.REMOTE_CONTAINERS = 'true'`.
- **Steps**:
  1. Call `getDefaultRemoteHost()`.
- **Expected result**: Returns `'localhost:38741'`.
- **Automation**: vitest.

---

- **Test name**: `getDefaultRemoteHost returns null outside devcontainer`
- **Priority**: P0
- **Type**: unit
- **Setup**: Clear all detection env vars.
- **Steps**:
  1. Call `getDefaultRemoteHost()`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

---

### 1.3 Remote Connection Argument Parsing

Tests for `--remote` flag parsing in `src/cli/args/global-args.ts`.

---

- **Test name**: `--remote with host:port passes through as-is`
- **Priority**: P0
- **Type**: unit
- **Setup**: Parse `--remote localhost:38741` through yargs.
- **Steps**:
  1. Parse args `['exec', '--remote', 'localhost:38741', 'print("hi")']`.
- **Expected result**: `argv.remote === 'localhost:38741'`.
- **Automation**: vitest.

---

- **Test name**: `--remote with host-only appends default port`
- **Priority**: P0
- **Type**: unit
- **Setup**: Parse `--remote myhost` through yargs.
- **Steps**:
  1. Parse args `['exec', '--remote', 'myhost', 'print("hi")']`.
- **Expected result**: `argv.remote === 'myhost:38741'`.
- **Automation**: vitest.

---

- **Test name**: `--remote with invalid port rejects`
- **Priority**: P1
- **Type**: unit
- **Setup**: Parse `--remote localhost:abc` through yargs.
- **Steps**:
  1. Parse args `['exec', '--remote', 'localhost:abc', 'print("hi")']`.
- **Expected result**: Yargs throws validation error about invalid port.
- **Automation**: vitest.

---

- **Test name**: `--remote and --local together produces conflict error`
- **Priority**: P1
- **Type**: unit
- **Setup**: Parse both flags through yargs.
- **Steps**:
  1. Parse args `['exec', '--remote', 'localhost:38741', '--local', 'print("hi")']`.
- **Expected result**: Yargs throws conflict error (mutually exclusive).
- **Automation**: vitest.

---

## 2. Integration Test Plans

### 2.1 BridgeConnection Remote Path

Tests for the remote connection path in `src/bridge/bridge-connection.ts`.

---

- **Test name**: `connectAsync with remoteHost connects as client, not host`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start a mock WebSocket server on a test port that accepts `/client` connections.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ remoteHost: 'localhost:<testPort>' })`.
  2. Verify the mock server received a WebSocket connection on `/client`.
  3. Verify the returned connection is in client mode (not host mode).
- **Expected result**: Connection established as client.
- **Automation**: vitest with real WebSocket server on ephemeral port.

---

- **Test name**: `connectAsync with remoteHost throws on ECONNREFUSED`
- **Priority**: P0
- **Type**: integration
- **Setup**: No server listening on the target port.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ remoteHost: 'localhost:19999' })`.
- **Expected result**: Rejects with error containing "Could not connect" and "studio-bridge serve".
- **Automation**: vitest.

---

- **Test name**: `connectAsync with remoteHost times out after 5 seconds`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start a TCP server that accepts connections but never completes the WebSocket handshake.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ remoteHost: 'localhost:<hangingPort>' })`.
  2. Measure time until rejection.
- **Expected result**: Rejects within 5-6 seconds with message containing "timed out".
- **Automation**: vitest with custom TCP server.

---

- **Test name**: `connectAsync with local: true skips devcontainer auto-detection`
- **Priority**: P0
- **Type**: integration
- **Setup**: Set `REMOTE_CONTAINERS=true`. Start a mock bridge host on 38741.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ local: true })`.
  2. Verify no connection attempt to 38741 as client.
  3. Verify it attempts local bind (or falls through to local behavior).
- **Expected result**: Auto-detection is skipped.
- **Automation**: vitest.

---

- **Test name**: `connectAsync auto-detects devcontainer and connects remotely`
- **Priority**: P0
- **Type**: integration
- **Setup**: Set `REMOTE_CONTAINERS=true`. Start a mock WebSocket server on port 38741 accepting `/client`.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({})` (no remoteHost, no local).
  2. Verify it connects to the mock server as a client.
- **Expected result**: Auto-detection triggers, connection established to localhost:38741.
- **Automation**: vitest.

---

- **Test name**: `connectAsync auto-detection falls back to local on timeout`
- **Priority**: P0
- **Type**: integration
- **Setup**: Set `REMOTE_CONTAINERS=true`. No server on 38741. Ensure local bind is possible on another port.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({})`.
  2. Measure time until it falls back.
  3. Verify a warning is logged.
- **Expected result**: Falls back to local mode within 3-4 seconds. Warning message mentions `studio-bridge serve`.
- **Automation**: vitest with console.warn spy.

---

## 3. End-to-End Test Plans

### 3.1 Serve Startup and Port Binding

- **Test name**: `serve starts and binds port, health endpoint responds`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>` as a subprocess.
- **Steps**:
  1. Wait for stdout to contain "listening on port".
  2. Send HTTP GET to `http://localhost:<testPort>/health`.
  3. Verify 200 response with valid JSON body.
- **Expected result**: Health endpoint responds. Subprocess is running.
- **Automation**: vitest with `child_process.spawn`.

---

### 3.2 Serve Graceful Shutdown (SIGTERM)

- **Test name**: `serve shuts down cleanly on SIGTERM`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>` as a subprocess. Connect a mock plugin via WebSocket using `MockPluginClient`.
- **Steps**:
  1. Wait for subprocess to be listening (stdout "listening on port").
  2. Connect mock plugin to `ws://localhost:<testPort>/plugin/<sessionId>`.
  3. Send SIGTERM to the subprocess.
  4. Wait for subprocess to exit.
  5. Verify exit code is 0.
  6. Verify the mock plugin's WebSocket received a close event or a `shutdown` message.
  7. Verify the port is no longer in use (can bind it from the test).
- **Expected result**: Exit code 0. Plugin notified. Port freed.
- **Automation**: vitest with `child_process.spawn` and `MockPluginClient`.

---

### 3.3 Serve with Port Already in Use

- **Test name**: `serve errors when port is already in use`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Bind a TCP server on port `<testPort>`.
- **Steps**:
  1. Start `studio-bridge serve --port <testPort>` as a subprocess.
  2. Wait for the subprocess to exit.
  3. Capture stderr/stdout.
- **Expected result**: Subprocess exits with code 1. Output contains "already in use" and "--port".
- **Automation**: vitest with `net.createServer`.

---

### 3.4 Remote Client Connection to Running Serve

- **Test name**: `remote client connects to running serve and executes command`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>` as a subprocess. Connect a mock plugin using `MockPluginClient` that responds to `execute` requests.
- **Steps**:
  1. Start serve subprocess, wait for "listening on port".
  2. Connect mock plugin via WebSocket to `ws://localhost:<testPort>/plugin/<sessionId>`. Mock plugin responds to `execute` with `scriptComplete` containing output "hello from remote".
  3. Run `studio-bridge exec --remote localhost:<testPort> 'print("hello")'` as a separate subprocess.
  4. Capture stdout from the exec subprocess.
- **Expected result**: Exec subprocess stdout contains "hello from remote". Exit code 0.
- **Automation**: vitest with multiple subprocesses and `MockPluginClient`.

---

### 3.5 Remote Client with Unreachable Host (Timeout)

- **Test name**: `remote client errors within 6 seconds when host is unreachable`
- **Priority**: P0
- **Type**: e2e
- **Setup**: No server on port 19999.
- **Steps**:
  1. Record start time.
  2. Run `studio-bridge exec --remote localhost:19999 'print("hi")'` as a subprocess.
  3. Wait for subprocess to exit.
  4. Record end time.
- **Expected result**: Exit code 1. Duration less than 6 seconds. Stderr contains "Could not connect".
- **Automation**: vitest with `child_process.spawn` and timer.

---

### 3.6 Remote Client with Wrong Port

- **Test name**: `remote client errors when port is wrong but host exists`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Attempt connection to `<testPort + 1>` (wrong port).
- **Steps**:
  1. Start serve on `<testPort>`.
  2. Run `studio-bridge exec --remote localhost:<testPort + 1> 'print("hi")'`.
  3. Wait for subprocess to exit.
- **Expected result**: Exit code 1. Error message contains "Could not connect" and the wrong port number.
- **Automation**: vitest.

---

### 3.7 Multiple Concurrent CLI Clients on One Daemon

- **Test name**: `multiple CLI clients can connect to one serve instance concurrently`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect a mock plugin using `MockPluginClient` that handles execute requests. The mock plugin should track request IDs to return distinct outputs.
- **Steps**:
  1. Start serve, wait for "listening on port".
  2. Connect mock plugin.
  3. Spawn CLI client A: `studio-bridge exec --remote localhost:<testPort> 'print("clientA")'`.
  4. Spawn CLI client B: `studio-bridge exec --remote localhost:<testPort> 'print("clientB")'` concurrently.
  5. Wait for both to complete.
  6. Capture stdout from each.
- **Expected result**: Client A receives output for client A's request. Client B receives output for client B's request. No cross-contamination. Both exit with code 0.
- **Automation**: vitest with concurrent subprocesses.

---

### 3.8 Daemon Restart While CLI is Mid-Request

- **Test name**: `CLI client gets error when daemon dies mid-request`
- **Priority**: P2
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect a mock plugin using `MockPluginClient` that delays its response by 5 seconds.
- **Steps**:
  1. Start serve, connect mock plugin (with delayed response).
  2. Spawn CLI client: `studio-bridge exec --remote localhost:<testPort> 'long_running()'`.
  3. Wait 1 second, then kill the serve subprocess with SIGKILL (not SIGTERM -- simulate crash).
  4. Wait for the CLI client subprocess to exit.
- **Expected result**: CLI client exits with code 1. Error message indicates connection was lost or request failed.
- **Automation**: vitest.

---

### 3.9 Devcontainer Auto-Detection with Env Vars

- **Test name**: `CLI auto-detects devcontainer and connects to remote bridge host`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port 38741` on a test port. Connect a mock plugin using `MockPluginClient`. Set `REMOTE_CONTAINERS=true` in the environment for the client subprocess.
- **Steps**:
  1. Start serve on port 38741, connect mock plugin.
  2. Spawn CLI client with `REMOTE_CONTAINERS=true` env: `studio-bridge exec 'print("auto")'` (no `--remote` flag).
  3. Wait for subprocess to exit.
  4. Capture stdout.
- **Expected result**: Output contains the plugin's response. The CLI connected automatically via auto-detection. Exit code 0.
- **Automation**: vitest with `child_process.spawn` and custom env.

---

### 3.10 Devcontainer Fallback to Local on Timeout

- **Test name**: `CLI falls back to local mode when devcontainer auto-detection fails`
- **Priority**: P1
- **Type**: e2e
- **Setup**: No bridge host running on port 38741. Set `REMOTE_CONTAINERS=true` in the environment.
- **Steps**:
  1. Record start time.
  2. Spawn CLI client with `REMOTE_CONTAINERS=true` env: `studio-bridge sessions` (a command that works in local mode with zero sessions).
  3. Wait for subprocess to exit.
  4. Record end time.
  5. Capture stderr and stdout.
- **Expected result**: Falls back to local mode. Stderr contains a warning about devcontainer detection failure. Duration between 3 and 5 seconds (3-second auto-detect timeout). Stdout shows empty session list or local behavior. Exit code 0.
- **Automation**: vitest with timer and custom env.

---

### 3.11 --local Flag Overrides Devcontainer Detection

- **Test name**: `--local flag skips devcontainer auto-detection`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port 38741`. Set `REMOTE_CONTAINERS=true`. Connect a mock plugin to serve using `MockPluginClient`.
- **Steps**:
  1. Start serve on 38741, connect mock plugin.
  2. Spawn CLI client with `REMOTE_CONTAINERS=true` env: `studio-bridge sessions --local`.
  3. Wait for subprocess to exit.
  4. Capture stdout and stderr.
- **Expected result**: The CLI does NOT connect to the remote serve instance. Instead, it enters local mode (tries to bind its own port or connects to a local host). The result should differ from what the remote serve would return. No warning about devcontainer detection. Exit code 0.
- **Automation**: vitest with custom env.

---

### 3.12 Wrong Message Routed to Wrong Plugin (Multi-Session)

- **Test name**: `daemon routes messages to correct plugin when multiple sessions are active`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect two mock plugins using `MockPluginClient` with different session IDs. Each plugin returns a different output (e.g., plugin A returns "from-A", plugin B returns "from-B").
- **Steps**:
  1. Start serve, wait for "listening on port".
  2. Connect mock plugin A with session ID `session-a`. Plugin A responds to execute with "from-A".
  3. Connect mock plugin B with session ID `session-b`. Plugin B responds to execute with "from-B".
  4. Spawn CLI client targeting session A: `studio-bridge exec --remote localhost:<testPort> --session session-a 'test()'`.
  5. Spawn CLI client targeting session B: `studio-bridge exec --remote localhost:<testPort> --session session-b 'test()'`.
  6. Wait for both to complete.
- **Expected result**: Client targeting session A receives "from-A". Client targeting session B receives "from-B". No message cross-routing.
- **Automation**: vitest with multiple `MockPluginClient` instances and concurrent subprocesses.

---

### 3.13 Daemon Cleanup After Test (Graceful)

- **Test name**: `daemon cleans up all resources on graceful shutdown`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect a mock plugin using `MockPluginClient` and a mock CLI client via WebSocket.
- **Steps**:
  1. Start serve, connect mock plugin and mock CLI client.
  2. Verify both connections are active (health endpoint shows 1 plugin session, 1 client).
  3. Send SIGTERM to the serve subprocess.
  4. Wait for subprocess to exit (max 5 seconds).
  5. Verify exit code is 0.
  6. Verify mock plugin received close event.
  7. Verify mock CLI client received close event.
  8. Verify the port is free (bind a new TCP server on it, then close).
  9. Verify no orphaned child processes or timers (subprocess fully exited).
- **Expected result**: All connections closed. Port freed. Exit code 0. No resource leaks.
- **Automation**: vitest with `child_process.spawn`, `MockPluginClient`, and `net.createServer`.

---

## 4. Edge Case Tests

### 4.1 Serve with --json Flag

- **Test name**: `serve --json outputs structured JSON lines`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort> --json`.
- **Steps**:
  1. Start serve with `--json`, wait for first JSON line on stdout.
  2. Parse the first line as JSON.
  3. Connect a mock plugin using `MockPluginClient`.
  4. Wait for the next JSON line on stdout.
  5. Parse it.
  6. Disconnect the mock plugin.
  7. Wait for the next JSON line on stdout.
- **Expected result**: First line: `{ "event": "started", "port": <testPort>, "timestamp": "..." }`. Second line: `{ "event": "pluginConnected", "sessionId": "...", ... }`. Third line: `{ "event": "pluginDisconnected", "sessionId": "..." }`. All lines are valid JSON.
- **Automation**: vitest.

---

### 4.2 Serve with --timeout Auto-Shutdown

- **Test name**: `serve --timeout shuts down after idle period`
- **Priority**: P2
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort> --timeout 2000` (2 second timeout).
- **Steps**:
  1. Start serve, wait for "listening on port".
  2. Wait 3 seconds (no connections made).
  3. Check if subprocess has exited.
- **Expected result**: Subprocess exits with code 0 after approximately 2 seconds of idle time. Stdout contains "Idle timeout reached".
- **Automation**: vitest with timer.

---

### 4.3 Serve --timeout Resets on Connection

- **Test name**: `serve --timeout resets when a connection arrives`
- **Priority**: P2
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort> --timeout 3000`.
- **Steps**:
  1. Start serve, wait for "listening on port".
  2. Wait 2 seconds.
  3. Connect a mock plugin using `MockPluginClient` (resets the timer).
  4. Disconnect the mock plugin immediately.
  5. Wait 2 seconds (timer should have restarted from disconnect).
  6. Verify serve is still running (timer has not expired yet -- only 2 of 3 seconds elapsed since last activity).
  7. Wait 2 more seconds.
  8. Verify serve has now exited.
- **Expected result**: Serve stays alive during and shortly after the connection. Exits after 3 seconds of idle following the disconnect.
- **Automation**: vitest with precise timing.

---

### 4.4 SIGHUP Does Not Kill Serve

- **Test name**: `serve ignores SIGHUP and continues running`
- **Priority**: P2
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>` as a subprocess.
- **Steps**:
  1. Start serve, wait for "listening on port".
  2. Send SIGHUP to the subprocess.
  3. Wait 1 second.
  4. Verify the subprocess is still running (send HTTP GET to health endpoint).
- **Expected result**: Subprocess survives SIGHUP. Health endpoint still responds.
- **Automation**: vitest with `process.kill(pid, 'SIGHUP')`.

---

## 5. Daemon Stays Alive Tests

### 5.1 Daemon Survives CLI Client Disconnect

- **Test name**: `daemon stays alive when CLI client disconnects`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect a mock plugin using `MockPluginClient` and a CLI client.
- **Steps**:
  1. Start serve, connect mock plugin and CLI client.
  2. CLI client disconnects.
  3. Verify daemon is still running (health endpoint responds).
  4. New CLI client connects and executes a command.
- **Expected result**: Daemon continues serving. New CLI client can execute commands. Mock plugin remains connected.
- **Automation**: vitest.

---

### 5.2 Daemon Survives Plugin Reconnect

- **Test name**: `daemon stays alive when plugin disconnects and reconnects`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge serve --port <testPort>`. Connect a mock plugin using `MockPluginClient`.
- **Steps**:
  1. Start serve, connect mock plugin.
  2. Disconnect mock plugin.
  3. Verify daemon is still running (health endpoint responds).
  4. Connect a new mock plugin with the same session ID.
  5. Connect a CLI client and execute a command targeting the session.
- **Expected result**: Daemon survives plugin disconnect. Reconnected plugin serves new commands.
- **Automation**: vitest with `MockPluginClient`.

---

## Phase 4 Gate

**Criteria**: Split server mode works. Daemon stays alive independently. Devcontainer auto-detection works. CLI clients can connect remotely. Messages are routed correctly to the right plugin session.

**Required passing tests (P0)**:
1. All Phase 3 gate tests (see `03-commands.md`).
2. `serveAsync calls BridgeConnection.connectAsync with keepAlive: true` (1.1).
3. `serveAsync throws clear error on EADDRINUSE` (1.1).
4. `isDevcontainer returns true when REMOTE_CONTAINERS is set` (1.2).
5. `isDevcontainer returns false when no signals are present` (1.2).
6. `connectAsync with remoteHost connects as client, not host` (2.1).
7. `connectAsync with remoteHost throws on ECONNREFUSED` (2.1).
8. `connectAsync auto-detects devcontainer and connects remotely` (2.1).
9. `connectAsync auto-detection falls back to local on timeout` (2.1).
10. `serve starts and binds port, health endpoint responds` (3.1).
11. `serve shuts down cleanly on SIGTERM` (3.2).
12. `serve errors when port is already in use` (3.3).
13. `remote client connects to running serve and executes command` (3.4).
14. `remote client errors within 6 seconds when host is unreachable` (3.5).
15. `daemon stays alive when CLI client disconnects` (5.1).

**Required passing tests (P1)**:
16. `daemon routes messages to correct plugin when multiple sessions are active` (3.12).
17. `daemon cleans up all resources on graceful shutdown` (3.13).
18. `--local flag skips devcontainer auto-detection` (3.11).
19. `multiple CLI clients can connect to one serve instance concurrently` (3.7).
20. `CLI auto-detects devcontainer and connects to remote bridge host` (3.9).
21. `CLI falls back to local mode when devcontainer auto-detection fails` (3.10).

**Manual verification** (requires devcontainer):
1. On host: run `studio-bridge serve`.
2. In devcontainer: run `studio-bridge exec 'print("hello")'` -- verify output appears.
3. In devcontainer: run `studio-bridge sessions` -- verify session listed.
4. Kill and restart `studio-bridge serve` on host -- verify devcontainer CLI reconnects on next command.
5. In devcontainer: run `studio-bridge exec --local 'print("test")'` -- verify it does NOT use the remote serve.
6. On host: run `studio-bridge serve --json` -- verify structured JSON events appear when plugin connects/disconnects.
