# Phase 4: Split Server Mode

Goal: Enable the workflow where Studio runs on the host OS but the CLI runs inside a devcontainer. The bridge host pattern from Phase 1 already provides the core mechanism -- `BridgeConnection` handles host/client role detection. The split server is an operational concern (how to start the host), not an API concern. No new abstractions, no daemon layer, no separate protocol. See `05-split-server.md` for the full spec.

References:
- Split server mode: `studio-bridge/plans/tech-specs/05-split-server.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/04-split-server.md`
- Validation: `studio-bridge/plans/execution/validation/04-split-server.md`
- Depends on Task 1.3 (bridge module) -- see `01-bridge-network.md`

---

### Task 4.1: Serve command -- thin wrapper

**Description**: Implement `studio-bridge serve` as a thin command handler in `src/commands/serve.ts` (following the same `CommandDefinition` pattern as all other commands). It calls `BridgeConnection.connectAsync({ keepAlive: true })` to start a headless bridge host that stays alive indefinitely. This is the same bridge host that any CLI process creates when it is first to bind port 38741 -- the only difference is that `serve` always becomes the host (never a client) and never exits on idle. Unlike the implicit host behavior (which falls back to client on EADDRINUSE), `serve` errors if the port is already in use.

**Files to create**:
- `src/commands/serve.ts` -- `CommandDefinition<ServeInput, CommandResult<ServeOutput>>` handler with `requiresSession: false`. Calls `BridgeConnection.connectAsync({ keepAlive: true })`, sets up SIGTERM/SIGINT signal handlers, logs status to stdout. Accepts `--port`, `--log-level`, `--json`, `--timeout` flags.

**Files to modify**:
- `src/commands/index.ts` -- add `serveCommand` to named exports and `allCommands` array.
- `src/cli/cli.ts` -- no change needed (it already loops over `allCommands`).

**Dependencies**: Task 1.3, Task 1.7.

**Complexity**: S

**Acceptance criteria**:
- `studio-bridge serve` binds port 38741 (or `--port N`) and stays alive until killed.
- Plugin can discover and connect via the `/health` endpoint.
- Other CLIs can connect as bridge clients.
- `--json` outputs structured status on stdout (for programmatic consumers).
- `--log-level` controls verbosity (silent, error, warn, info, debug).
- `--timeout <ms>` enables auto-shutdown after idle period with no connections (default: none).
- SIGTERM/SIGINT trigger graceful `disconnectAsync()` (which runs the hand-off protocol).
- If port 38741 is already in use, prints a clear error: "Port 38741 is already in use. A bridge host is already running. Connect as a client with any studio-bridge command, or use --port to start on a different port."
- There is NO `src/cli/commands/serve-command.ts` -- the command lives in `src/commands/serve.ts` like all other commands.
- There is NO `src/server/daemon-server.ts` or `src/server/daemon-client.ts` -- the serve command uses `bridge-host.ts` from `src/bridge/internal/` directly via `BridgeConnection`.

### Task 4.2: Remote bridge client (devcontainer CLI)

**Description**: When the CLI runs inside a devcontainer (or when `--remote` is specified), `BridgeConnection.connectAsync()` connects to a remote bridge host instead of trying to bind locally. The CLI is just a bridge client pointing at a different host. No separate "daemon client" abstraction is needed -- `bridge-client.ts` from `src/bridge/internal/` already handles this.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- add `remoteHost?: string` to `BridgeConnectionOptions`. When set, skip the local bind attempt and connect directly as a client to the specified host via the existing `bridge-client.ts`.
- `src/cli/args/global-args.ts` -- add `--remote` flag (e.g., `--remote localhost:38741`) and `--local` flag (force local mode, disable auto-detection).

**Dependencies**: Task 1.3.

**Complexity**: S

**Acceptance criteria**:
- `studio-bridge exec --remote localhost:38741 'print("hi")'` connects as a bridge client to the remote host and executes.
- `studio-bridge exec --local 'print("hi")'` forces local mode even inside a devcontainer.
- All commands work through the remote connection: `exec`, `run`, `terminal`, `state`, `screenshot`, `logs`, `query`, `sessions`.
- Connection errors produce clear messages: "Could not connect to bridge host at localhost:38741. Is `studio-bridge serve` or `studio-bridge terminal --keep-alive` running on the host?"

### Task 4.3: Devcontainer auto-detection

**Description**: When running inside a devcontainer, automatically try connecting to a remote bridge host before falling back to local mode. Detection is based on the `REMOTE_CONTAINERS` or `CODESPACES` environment variables, or the existence of `/.dockerenv`. The detection utility lives inside the bridge module's internal directory because it is part of the connection logic -- not visible to consumers.

**Files to create**:
- `src/bridge/internal/environment-detection.ts` -- `isDevcontainer(): boolean`, `getDefaultRemoteHost(): string | null`. Uses environment variable checks and file existence checks.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- in `connectAsync`, if `remoteHost` is not set but `isDevcontainer()` is true, attempt remote connection to `localhost:38741` before falling back to local bind.

**Dependencies**: Task 4.2. **Must complete before Task 6.5 starts** (sequential chain: 4.2 -> 4.3 -> 6.5 -- all modify `bridge-connection.ts`).

**Complexity**: S

**Acceptance criteria**:
- Inside a devcontainer with a bridge host running on the host (port-forwarded), `studio-bridge exec 'print("hi")'` works without `--remote` flag.
- Outside a devcontainer, behavior is unchanged (local host/client detection).
- If the remote host is not reachable from inside devcontainer, falls back to local mode with a warning.
- The environment detection module is in `src/bridge/internal/` (not `src/server/`) -- it is internal to the bridge module.

### Parallelization within Phase 4

Tasks 4.1 and 4.2 both depend only on Task 1.3 (bridge module) and can proceed in parallel. Task 4.1 also depends on 1.7 (command handler infra) for the `CommandDefinition` pattern. Task 4.3 depends on 4.2.

> **Sequential chain (bridge-connection.ts)**: Tasks 4.2, 4.3, and 6.5 all modify `bridge-connection.ts` and MUST be sequenced: 4.2 -> 4.3 -> 6.5. Do NOT run them in parallel. Task 6.5 (CI integration, Phase 6) is included in this chain because it modifies the same file.

```
4.1 (serve command) ------------------------------------------------+
                                                                     +--> (both done)
4.2 (remote client) --> 4.3 (auto-detection) --> 6.5 (CI integration)|
```

---

## Testing Strategy (Phase 4)

**Integration tests**:
- Start `studio-bridge serve` (bridge host), connect mock plugin, connect CLI as bridge client via `--remote`, execute script, verify output.
- Kill CLI client, verify bridge host stays alive.
- Kill bridge host, verify plugin detects disconnect and polls for reconnection.
- Start `studio-bridge terminal --keep-alive`, connect from a second CLI as client, verify commands relay correctly.

**Manual testing** (devcontainer):
- Start `studio-bridge serve` (or `terminal --keep-alive`) on host.
- Inside devcontainer, run `studio-bridge exec 'print("hello")'` -- verify auto-detection and relay via port-forwarded 38741.
- Verify port forwarding works.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 4.1 (serve command) | `serve` command fails because `BridgeConnection.connectAsync({ keepAlive: true })` does not prevent idle exit as expected | Self-fix: verify that `keepAlive: true` disables the 5-second idle timer. Add a test that starts `serve`, waits 10 seconds with no connections, and verifies the process is still alive. |
| 4.1 (serve command) | Port 38741 is already in use by a non-bridge process, and the error message is confusing | Self-fix: detect `EADDRINUSE`, check if the existing process is a bridge host (via `/health`), and print a specific error message for each case. |
| 4.2 (remote client) | `--remote` connection fails because the remote host's WebSocket server rejects the client path | Self-fix: ensure the remote host accepts `/client` connections. Add a test that connects via `--remote localhost:<port>`. |
| 4.2 (remote client) | Remote connection latency causes action timeouts that work fine locally | Self-fix: increase default timeouts when `remoteHost` is set. Add a `--timeout` override flag. |
| 4.3 (auto-detection) | Devcontainer detection returns false positive (running in Docker but not a devcontainer) | Self-fix: use multiple signals (`REMOTE_CONTAINERS`, `CODESPACES`, `/.dockerenv`) and require at least one to match. Log which signal triggered detection. |
| 4.3 (auto-detection) | Port forwarding from host to devcontainer is not set up, causing silent connection failure | Self-fix: when remote connection fails after auto-detection, print a clear error with instructions to add port 38741 to `forwardPorts` in `devcontainer.json`. Fall back to local mode. |
