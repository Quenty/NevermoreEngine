# Phase 4: Split Server Mode -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/04-split-server.md](../phases/04-split-server.md)
**Validation**: [studio-bridge/plans/execution/validation/04-split-server.md](../validation/04-split-server.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/04-split-server.md](../phases/04-split-server.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `disconnectAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output
- **Copy the `sessions` command pattern**: Every command follows the handler/wiring split established by `src/commands/sessions.ts` and `src/cli/commands/sessions-command.ts` (Task 1.7b). Use `resolveSession()` from `src/cli/resolve-session.ts` and `formatOutput()` from `src/cli/format-output.ts`.
- **Barrel export pattern for command registration**: When adding a new command, add its export to `src/commands/index.ts` and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already registers all commands via a loop over `allCommands` (established in Task 1.7b).
- **Consumer invariant**: No code outside `src/bridge/internal/` should know or care whether the bridge host is implicit (first CLI process) or explicit (`studio-bridge serve`). `BridgeConnection` works identically in both cases. Any change that leaks this distinction to consumers is a design violation.

---

## Task 4.1: Serve Command (`studio-bridge serve`)

**Prerequisites**: Tasks 1.3d5 (BridgeConnection barrel export) and 1.7a (shared CLI utilities) must be completed first.

**Context**: Split-server mode separates the bridge host and CLI into two processes, typically on two different machines (host OS and devcontainer). The `serve` command starts a dedicated bridge host that stays alive indefinitely, accepting connections from both Studio plugins and CLI clients. This is the same bridge host that any CLI process creates implicitly when it is the first to bind port 38741 -- the only difference is that `serve` always becomes the host (never falls back to client mode) and never exits on idle.

**Objective**: Implement `studio-bridge serve` as a `CommandDefinition` handler in `src/commands/serve.ts`. This is a thin wrapper around `BridgeConnection.connectAsync({ keepAlive: true })` with signal handling, structured logging, and port contention error handling.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/commands/sessions.ts` (the reference command handler -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/sessions-command.ts` (the reference CLI wiring -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (the `BridgeConnection` class with `connectAsync`)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (the bridge host implementation -- `serve` uses this indirectly via `BridgeConnection`)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/commands/index.ts` (barrel file -- add the new command here)
- `studio-bridge/plans/tech-specs/05-split-server.md` sections 4 and 5 (serve command spec, file layout)

**Files to Create**:
- `src/commands/serve.ts` -- `CommandDefinition<ServeInput, CommandResult<ServeOutput>>` handler
- `src/cli/commands/serve-command.ts` -- CLI wiring (yargs `CommandModule`)
- `src/commands/serve.test.ts` -- unit tests for the serve command handler

**Files to Modify**:
- `src/commands/index.ts` -- add `serveCommand` to named exports and `allCommands` array. Do NOT modify `cli.ts`.

**Requirements**:

1. Create `src/commands/serve.ts` following the same structure as `src/commands/sessions.ts`:

```typescript
import type { BridgeConnection } from '../bridge/bridge-connection.js';
import type { CommandResult } from '../cli/types.js';

export interface ServeInput {
  port?: number;
  logLevel?: 'silent' | 'error' | 'warn' | 'info' | 'debug';
  json?: boolean;
  timeout?: number;
}

export interface ServeOutput {
  port: number;
  sessions: Array<{ id: string; context: string; instanceId: string }>;
}

export async function serveAsync(
  options: ServeInput = {}
): Promise<CommandResult<ServeOutput>> {
  const port = options.port ?? 38741;

  // 1. Call BridgeConnection.connectAsync({ port, keepAlive: true }).
  //    This internally calls bridge-host.ts to start the WebSocket server.
  //    If keepAlive is true, the host never exits on idle (no 5-second grace period).
  //
  // 2. If connectAsync throws with code EADDRINUSE:
  //    - Do NOT fall back to client mode (unlike implicit host behavior).
  //    - Throw a clear error: "Port <port> is already in use. A bridge host is
  //      already running. Connect as a client with any studio-bridge command,
  //      or use --port to start on a different port."
  //    - Exit code 1.
  //
  // 3. On success, log the startup message:
  //    - Human-readable (default): "Bridge host listening on port <port>"
  //    - JSON mode (--json): { "event": "started", "port": <port>, "timestamp": "<ISO>" }
  //
  // 4. Set up event listeners for session connect/disconnect:
  //    - On plugin connect: log "Plugin connected: <sessionId> (<context>)"
  //    - On plugin disconnect: log "Plugin disconnected: <sessionId>"
  //    - On client connect: log "Client connected"
  //    - On client disconnect: log "Client disconnected"
  //    - In JSON mode, these are JSON lines: { "event": "pluginConnected", "sessionId": "...", ... }
  //
  // 5. The function does NOT return until the process is killed or --timeout expires.
  //    Use a Promise that resolves on shutdown signal.
}
```

2. Create `src/cli/commands/serve-command.ts` following `src/cli/commands/sessions-command.ts`:
   - Command: `serve`
   - Description: `Start a dedicated bridge host process`
   - Args:
     - `--port <number>` (default: 38741) -- port to listen on
     - `--log-level <level>` (choices: silent, error, warn, info, debug; default: info) -- log verbosity
     - `--json` (boolean, default: false) -- print structured status to stdout as JSON lines
     - `--timeout <ms>` (number, default: none) -- auto-shutdown after idle period with no connections
   - Handler:
     - Call `serveAsync(options)` with the parsed flags
     - The handler blocks until SIGTERM/SIGINT or timeout
     - Output is handled within `serveAsync` (streaming log output, not a single result)

3. Register in `src/commands/index.ts` (NOT `cli.ts`):

```typescript
// In src/commands/index.ts, add:
export { serveCommand } from './serve.js';

// And add to the allCommands array:
import { serveCommand } from './serve.js';
// ... serveCommand in the allCommands array
```

4. Implement signal handling inside the serve command handler:

   **SIGTERM / SIGINT** -- Graceful shutdown sequence:
   1. Log: "Shutting down..." (or `{ "event": "shuttingDown", "timestamp": "..." }` in JSON mode).
   2. Send `shutdown` notification to all connected plugins. This tells the plugin to cleanly disconnect rather than enter its reconnection polling loop.
   3. Close all WebSocket connections (both plugin and client connections).
   4. Unbind the port (stop the HTTP server).
   5. Log: "Bridge host stopped." (or `{ "event": "stopped", "timestamp": "..." }` in JSON mode).
   6. Exit with code 0.

   The graceful shutdown is implemented by calling `connection.disconnectAsync()` inside the signal handler. The `disconnectAsync` method on `BridgeConnection` already handles the hand-off protocol (transfer host role to a connected client if one exists, otherwise shut down). For `serve`, since we want a clean exit, we call `disconnectAsync()` and then `process.exit(0)`.

   **SIGHUP** -- Ignore. The serve process should survive terminal close (e.g., when run in a detached tmux session or via nohup). Register `process.on('SIGHUP', () => {})` to prevent the default SIGHUP behavior (which is to terminate).

   **Signal handler registration**:

```typescript
// Inside the serveAsync function, after BridgeConnection is established:
const shutdownAsync = async () => {
  log('Shutting down...');
  await connection.disconnectAsync();
  log('Bridge host stopped.');
  process.exit(0);
};

process.on('SIGTERM', () => void shutdownAsync());
process.on('SIGINT', () => void shutdownAsync());
process.on('SIGHUP', () => { /* ignore -- survive terminal close */ });
```

5. Implement the `--timeout` flag:

   When `--timeout <ms>` is provided, start a timer that resets whenever a plugin or client connects or sends a message. If the timer expires with zero active connections, trigger the same graceful shutdown sequence as SIGTERM. Log: "Idle timeout reached (<ms>ms with no connections). Shutting down."

   Implementation: use `setTimeout`/`clearTimeout` with a counter of active connections. On connection open, increment counter and clear the timer. On connection close, decrement counter and restart the timer if counter reaches zero.

6. Exit codes:
   - `0` -- Clean shutdown (SIGTERM, SIGINT, or idle timeout)
   - `1` -- Startup failure (port in use and not recoverable, invalid arguments)

7. Create `src/commands/serve.test.ts` with these unit tests:

```typescript
describe('serve command', () => {
  it('calls BridgeConnection.connectAsync with keepAlive: true', async () => {
    // Mock BridgeConnection.connectAsync, verify keepAlive is set
  });

  it('passes port option to connectAsync', async () => {
    // serveAsync({ port: 39000 }) -> connectAsync({ port: 39000, keepAlive: true })
  });

  it('throws clear error on EADDRINUSE', async () => {
    // Mock connectAsync to throw EADDRINUSE
    // Verify error message contains "already in use" and "--port"
  });

  it('logs startup message in human-readable mode', async () => {
    // Verify stdout contains "Bridge host listening on port 38741"
  });

  it('logs startup message in JSON mode', async () => {
    // serveAsync({ json: true })
    // Verify stdout contains parseable JSON with event: "started"
  });
});
```

**Acceptance Criteria**:
- `studio-bridge serve` binds port 38741 (or `--port N`) and stays alive until killed.
- Plugin can discover and connect via the `/health` endpoint on the bound port.
- Other CLIs can connect as bridge clients via the `/client` WebSocket path.
- `--json` outputs structured JSON lines to stdout on startup and on session events.
- `--log-level` controls verbosity (silent suppresses all output; debug shows WebSocket frame details).
- `--timeout <ms>` enables auto-shutdown after idle period with no active connections (default: no timeout, runs forever).
- SIGTERM/SIGINT trigger graceful shutdown: notify plugins, close WebSockets, unbind port, exit 0.
- SIGHUP is ignored (process survives terminal close).
- If port 38741 is already in use, prints: "Port 38741 is already in use. A bridge host is already running. Connect as a client with any studio-bridge command, or use --port to start on a different port." and exits with code 1.
- There is NO `src/cli/commands/serve-command.ts` separate from the command pattern -- the wiring follows the same `CommandModule` pattern as all other commands.
- There is NO `src/server/daemon-server.ts` -- the serve command uses `bridge-host.ts` from `src/bridge/internal/` directly via `BridgeConnection`.
- **End-to-end test**: Start `studio-bridge serve` in a subprocess. Connect a mock plugin via WebSocket to `ws://localhost:38741/plugin`. Send SIGTERM to the subprocess. Verify: (a) the mock plugin receives a `shutdown` message or the WebSocket closes cleanly, (b) the subprocess exits with code 0, (c) the port is unbound (a new process can bind it).

**Do NOT**:
- Create a separate daemon module or server directory. The serve command is a thin wrapper.
- Fall back to client mode on EADDRINUSE. This is an explicit host request; silent fallback would be confusing.
- Modify `cli.ts` to register the command -- add it to `src/commands/index.ts` instead.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 4.2: Remote Bridge Client (`--remote` / `--local` flags)

**Prerequisites**: Task 1.3d5 (BridgeConnection barrel export) must be completed first.

**Context**: When the CLI runs inside a devcontainer, it cannot bind the bridge port locally (Studio is on a different machine). Instead, it needs to connect as a client to a remote bridge host. The `--remote` flag lets users explicitly specify the remote host address. The `--local` flag forces local mode, disabling auto-detection. These are GLOBAL flags on the yargs root (not per-command) because they affect `BridgeConnection` behavior for every command.

**Objective**: Add `remoteHost?: string` support to `BridgeConnectionOptions` so the CLI can connect to a remote bridge host instead of trying to bind locally. Add `--remote` and `--local` as global CLI flags. No new abstractions -- the existing `bridge-client.ts` from `src/bridge/internal/` already knows how to connect as a client.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (the `BridgeConnection` class with `connectAsync` -- you will modify this)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (the client implementation -- already exists, used when connecting as client)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (the host implementation -- you need to understand when this is used vs. bridge-client)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/args/global-args.ts` (global CLI argument definitions -- add --remote and --local here)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/cli.ts` (the main CLI entry point -- understand how global args are threaded to commands)
- `studio-bridge/plans/tech-specs/05-split-server.md` section 6 (client connection spec, decision flow)

**Files to Modify**:
- `src/bridge/bridge-connection.ts` -- add `remoteHost?: string` to `BridgeConnectionOptions`. Modify `connectAsync` to skip local bind when `remoteHost` is set.
- `src/cli/args/global-args.ts` -- add `--remote <host:port>` and `--local` to `StudioBridgeGlobalArgs`.

**Files to Create**:
- `src/bridge/bridge-connection.test.ts` -- unit tests for the remote connection path (if not already existing; otherwise add tests to the existing file)

**Requirements**:

1. Add `remoteHost` to `BridgeConnectionOptions`:

```typescript
// In src/bridge/types.ts or bridge-connection.ts (wherever BridgeConnectionOptions is defined)
export interface BridgeConnectionOptions {
  port?: number;
  timeoutMs?: number;
  keepAlive?: boolean;
  remoteHost?: string;  // e.g., 'localhost:38741' or '192.168.1.5:38741'
  local?: boolean;       // force local mode, disable devcontainer auto-detection
}
```

2. Modify `BridgeConnection.connectAsync()` to handle `remoteHost`:

```typescript
// Modified decision flow in connectAsync:
static async connectAsync(options: BridgeConnectionOptions = {}): Promise<BridgeConnection> {
  // 1. If remoteHost is set:
  //    - Parse host:port. If only host is given (no colon), append default port 38741.
  //    - Validate format: must be "host:port" where port is a number 1-65535.
  //    - Skip local port-bind attempt entirely.
  //    - Connect as client to ws://<remoteHost>/client via bridge-client.ts.
  //    - On connection refused: throw with message:
  //      "Could not connect to bridge host at <host:port>.
  //       Is `studio-bridge serve` running on the host?"
  //    - On timeout (5 seconds): throw with message:
  //      "Connection to bridge host at <host:port> timed out after 5 seconds.
  //       Check that the host is reachable and port forwarding is configured."
  //
  // 2. If local is set:
  //    - Skip devcontainer auto-detection (Task 4.3).
  //    - Proceed directly to local bind attempt (standard implicit host behavior).
  //
  // 3. Otherwise (neither remoteHost nor local):
  //    - [Task 4.3 will add devcontainer auto-detection here]
  //    - Try binding port (become host); EADDRINUSE -> connect as client.
}
```

3. Parse the `--remote` flag as a global yargs option:

```typescript
// In src/cli/args/global-args.ts, add to the global options:
remote: {
  type: 'string',
  description: 'Connect to a remote bridge host at host:port (e.g., localhost:38741)',
  global: true,
  coerce: (value: string): string => {
    // If value contains no colon, append default port
    if (!value.includes(':')) {
      return `${value}:38741`;
    }
    // Validate port is a number
    const [host, portStr] = value.split(':');
    const port = parseInt(portStr, 10);
    if (isNaN(port) || port < 1 || port > 65535) {
      throw new Error(`Invalid port in --remote: ${portStr}. Must be 1-65535.`);
    }
    return `${host}:${port}`;
  },
},
local: {
  type: 'boolean',
  description: 'Force local mode (disable devcontainer auto-detection)',
  global: true,
  default: false,
  conflicts: 'remote',  // --remote and --local are mutually exclusive
},
```

4. Thread the global flags into `BridgeConnectionOptions`:

   In the CLI handler chain (wherever `BridgeConnection.connectAsync()` is called from CLI commands), pass `remoteHost` and `local` from the parsed global args:

```typescript
// In each command handler (or in a shared middleware):
const connection = await BridgeConnection.connectAsync({
  port: argv.port,
  remoteHost: argv.remote,
  local: argv.local,
});
```

5. Type signature for the parsed `--remote` flag:

```typescript
// In StudioBridgeGlobalArgs (global-args.ts)
export interface StudioBridgeGlobalArgs {
  // ... existing fields ...
  remote?: string;  // "host:port" after coercion
  local?: boolean;
}
```

6. Error handling -- connection refused:

   When `remoteHost` is set and the connection fails with `ECONNREFUSED`:
   ```
   Error: Could not connect to bridge host at localhost:38741.
   Is `studio-bridge serve` running on the host?
   ```

   When `remoteHost` is set and the connection times out (5 second default):
   ```
   Error: Connection to bridge host at localhost:38741 timed out after 5 seconds.
   Check that the host is reachable and port forwarding is configured.
   ```

   When `remoteHost` has an invalid format:
   ```
   Error: Invalid --remote value: "foo:bar". Expected format: host:port (e.g., localhost:38741).
   ```

7. Add tests to `src/bridge/bridge-connection.test.ts`:

```typescript
describe('BridgeConnection.connectAsync with remoteHost', () => {
  it('connects as client when remoteHost is set', async () => {
    // Start a mock WebSocket server on a test port.
    // Call connectAsync({ remoteHost: 'localhost:<testPort>' }).
    // Verify a client connection is made (not a host bind).
  });

  it('appends default port when remoteHost has no colon', async () => {
    // connectAsync({ remoteHost: 'myhost' })
    // Verify connection attempt to myhost:38741
  });

  it('throws ECONNREFUSED with clear message when host is unreachable', async () => {
    // connectAsync({ remoteHost: 'localhost:19999' }) -- nothing listening
    // Verify error message contains "Could not connect" and "studio-bridge serve"
  });

  it('throws timeout error after 5 seconds when host does not respond', async () => {
    // Use a server that accepts TCP but never completes the WebSocket handshake
    // connectAsync({ remoteHost: 'localhost:<hangingPort>' })
    // Verify error within ~5 seconds, message contains "timed out"
  });

  it('rejects when --remote and --local are both set', async () => {
    // This is handled at the yargs level via conflicts, but verify behavior
  });

  it('skips local bind attempt when remoteHost is set', async () => {
    // Start a real bridge host on port 38741.
    // Call connectAsync({ remoteHost: 'localhost:38741' }).
    // Verify the connection is as a CLIENT (not a second host).
    // The test port should remain available for binding by another process.
  });
});
```

**Acceptance Criteria**:
- `studio-bridge exec --remote localhost:38741 'print("hi")'` connects as a bridge client to the remote host and executes the script. Output is printed as if running locally.
- `studio-bridge exec --remote myhost 'print("hi")'` connects to `myhost:38741` (default port appended).
- `studio-bridge exec --local 'print("hi")'` forces local mode even inside a devcontainer (ignores auto-detection from Task 4.3).
- `--remote` and `--local` are mutually exclusive. Passing both produces a yargs validation error.
- All commands work through the remote connection: `exec`, `run`, `terminal`, `state`, `screenshot`, `logs`, `query`, `sessions`. The remote connection is transparent to the command handlers.
- Connection refused (`ECONNREFUSED`) produces: "Could not connect to bridge host at `<host:port>`. Is `studio-bridge serve` running on the host?"
- Connection timeout (5 seconds) produces: "Connection to bridge host at `<host:port>` timed out after 5 seconds. Check that the host is reachable and port forwarding is configured."
- Invalid `--remote` format produces a clear validation error with the expected format.
- **End-to-end test**: Start `studio-bridge serve --port 38742` in a subprocess. In a separate process, run `studio-bridge exec --remote localhost:38742 'print("hello")'`. Verify the output contains "hello". Then run `studio-bridge sessions --remote localhost:38742` and verify it lists the connected session.
- **End-to-end test (unreachable)**: Run `studio-bridge exec --remote localhost:19999 'print("hi")'`. Verify the process exits with code 1 within 6 seconds and the error message contains "Could not connect".

**Do NOT**:
- Create a separate "daemon client" abstraction. The existing `bridge-client.ts` from `src/bridge/internal/` is the client. `remoteHost` just changes which address it connects to.
- Make consumers aware of whether they are in local or remote mode. `BridgeSession` methods work identically.
- Modify `cli.ts` for command registration -- add to `src/commands/index.ts` instead.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 4.3: Devcontainer Auto-Detection

**Prerequisites**: Task 4.2 (remote bridge client) must be completed first. Tasks 4.2, 4.3, and 6.5 all modify `bridge-connection.ts` and must be sequenced: 4.2 then 4.3 then 6.5.

**Context**: When the CLI runs inside a devcontainer (VS Code Dev Containers, GitHub Codespaces, Docker Compose), it should automatically try connecting to a remote bridge host before falling back to local mode. This avoids requiring users to manually pass `--remote` every time. Detection is based on well-known environment variables and file markers. The `--remote` flag takes precedence over auto-detection, and `--local` disables it entirely.

**Objective**: Create `src/bridge/internal/environment-detection.ts` with `isDevcontainer()` and `getDefaultRemoteHost()` functions. Wire them into `BridgeConnection.connectAsync()` so that CLI processes inside devcontainers automatically attempt remote connection with a 3-second timeout before falling back to local mode.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (you will modify this -- the `connectAsync` decision flow)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (understand the host side)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (understand the client side)
- `studio-bridge/plans/tech-specs/05-split-server.md` section 6 (decision flow diagram, devcontainer auto-detection spec)

**Files to Create**:
- `src/bridge/internal/environment-detection.ts` -- `isDevcontainer(): boolean`, `getDefaultRemoteHost(): string | null`
- `src/bridge/internal/environment-detection.test.ts` -- unit tests for detection logic

**Files to Modify**:
- `src/bridge/bridge-connection.ts` -- add auto-detection step in `connectAsync` between the `remoteHost` check and the local bind attempt

**Requirements**:

1. Create `src/bridge/internal/environment-detection.ts`:

```typescript
import { existsSync } from 'node:fs';

const DEFAULT_BRIDGE_PORT = 38741;

/**
 * Detect whether the current process is running inside a devcontainer.
 *
 * Checks multiple signals to minimize false positives:
 * - REMOTE_CONTAINERS: set by VS Code Remote - Containers extension
 * - CODESPACES: set by GitHub Codespaces
 * - CONTAINER: set by some container runtimes
 * - /.dockerenv: file created by Docker in every container
 *
 * Returns true if ANY of these signals are present. This intentionally
 * casts a wide net -- the consequence of a false positive is a 3-second
 * timeout delay followed by a fallback to local mode, which is acceptable.
 * The consequence of a false negative is that the user must manually pass
 * --remote, which has clear error messaging.
 */
export function isDevcontainer(): boolean {
  return !!(
    process.env.REMOTE_CONTAINERS ||
    process.env.CODESPACES ||
    process.env.CONTAINER ||
    existsSync('/.dockerenv')
  );
}

/**
 * Get the default remote host address for devcontainer environments.
 *
 * Returns "localhost:38741" when inside a devcontainer (port forwarding
 * maps localhost inside the container to the host OS). Returns null when
 * not in a devcontainer.
 *
 * Why localhost and not host.docker.internal:
 * VS Code Dev Containers and Codespaces use port forwarding, which makes
 * the host's port 38741 accessible at localhost:38741 inside the container.
 * Docker Compose users configure port forwarding explicitly. In all cases,
 * localhost is the correct address from the container's perspective.
 */
export function getDefaultRemoteHost(): string | null {
  if (isDevcontainer()) {
    return `localhost:${DEFAULT_BRIDGE_PORT}`;
  }
  return null;
}
```

2. Create `src/bridge/internal/environment-detection.test.ts`:

```typescript
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { isDevcontainer, getDefaultRemoteHost } from './environment-detection.js';

describe('isDevcontainer', () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    // Clear all detection env vars before each test
    delete process.env.REMOTE_CONTAINERS;
    delete process.env.CODESPACES;
    delete process.env.CONTAINER;
  });

  afterEach(() => {
    // Restore original environment
    process.env = { ...originalEnv };
    vi.restoreAllMocks();
  });

  it('returns true when REMOTE_CONTAINERS is set', () => {
    process.env.REMOTE_CONTAINERS = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns true when CODESPACES is set', () => {
    process.env.CODESPACES = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns true when CONTAINER is set', () => {
    process.env.CONTAINER = 'podman';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns true when /.dockerenv exists', () => {
    // Mock existsSync to return true for /.dockerenv
    vi.mock('node:fs', () => ({
      existsSync: (path: string) => path === '/.dockerenv',
    }));
    // Re-import after mock
    expect(isDevcontainer()).toBe(true);
  });

  it('returns false when no detection signals are present', () => {
    // No env vars set, /.dockerenv does not exist (default on host OS)
    expect(isDevcontainer()).toBe(false);
  });

  it('returns true when multiple signals are present', () => {
    process.env.REMOTE_CONTAINERS = 'true';
    process.env.CODESPACES = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('treats empty string env var as falsy', () => {
    process.env.REMOTE_CONTAINERS = '';
    expect(isDevcontainer()).toBe(false);
  });
});

describe('getDefaultRemoteHost', () => {
  it('returns localhost:38741 when inside devcontainer', () => {
    process.env.REMOTE_CONTAINERS = 'true';
    expect(getDefaultRemoteHost()).toBe('localhost:38741');
  });

  it('returns null when not inside devcontainer', () => {
    delete process.env.REMOTE_CONTAINERS;
    delete process.env.CODESPACES;
    delete process.env.CONTAINER;
    expect(getDefaultRemoteHost()).toBeNull();
  });
});
```

3. Modify `src/bridge/bridge-connection.ts` -- add auto-detection to the `connectAsync` decision flow:

```typescript
import { isDevcontainer, getDefaultRemoteHost } from './internal/environment-detection.js';

// The complete decision flow in connectAsync:
static async connectAsync(options: BridgeConnectionOptions = {}): Promise<BridgeConnection> {
  // Step 1: Explicit --remote takes highest precedence
  if (options.remoteHost) {
    return this._connectAsClientAsync(options.remoteHost, options);
    // On failure: throw with clear error message (no fallback)
  }

  // Step 2: Devcontainer auto-detection (unless --local is set)
  if (!options.local) {
    const autoRemoteHost = getDefaultRemoteHost();
    if (autoRemoteHost) {
      try {
        // Use a shorter timeout (3 seconds) for auto-detection.
        // If the bridge host is not running on the host OS, we want to
        // fall back quickly rather than making the user wait.
        return await this._connectAsClientAsync(autoRemoteHost, {
          ...options,
          timeoutMs: 3000,
        });
      } catch (error) {
        // Auto-detection failed -- fall back to local mode with a warning.
        // This is NOT an error because the user did not explicitly request
        // remote mode. The warning helps them understand what happened.
        console.warn(
          `Devcontainer detected, but could not connect to bridge host at ${autoRemoteHost}. ` +
          `Falling back to local mode. Run \`studio-bridge serve\` on the host OS, ` +
          `or use --remote to specify a different address.`
        );
      }
    }
  }

  // Step 3: Local mode -- try binding port (become host); EADDRINUSE -> connect as client
  return this._connectLocalAsync(options);
}
```

   **Important sequencing note**: This modification to `bridge-connection.ts` MUST happen AFTER Task 4.2 is complete. Task 4.2 adds the `remoteHost` handling and `_connectAsClientAsync` method. Task 4.3 inserts the auto-detection step between the `remoteHost` check and the local bind attempt. Do NOT run Tasks 4.2 and 4.3 in parallel -- they both modify `connectAsync` and must be sequenced: 4.2 then 4.3.

4. Auto-detection timeout behavior:

   - The auto-detection connection attempt uses a **3-second timeout** (not the default 5 seconds used by explicit `--remote`). This is shorter because auto-detection is speculative -- if the host is not reachable, we want to fall back quickly.
   - On timeout or `ECONNREFUSED`, log a warning and fall back to local mode. Do NOT throw an error. The user did not explicitly request remote mode.
   - The warning message should be actionable: tell the user to run `studio-bridge serve` on the host or use `--remote`.

5. Override precedence (highest to lowest):
   1. `--remote <host:port>` -- connect to specified host, error on failure (no fallback)
   2. `--local` -- force local mode, skip auto-detection entirely
   3. Devcontainer auto-detection -- if detected, try remote with 3s timeout, fall back to local
   4. Default local behavior -- bind port or connect as client

**Acceptance Criteria**:
- Inside a devcontainer (with `REMOTE_CONTAINERS=true` or `CODESPACES=true` env var), `studio-bridge exec 'print("hi")'` automatically tries connecting to `localhost:38741` as a client.
- If the remote host is reachable (bridge host running on host OS with port forwarding), the command executes successfully without `--remote`.
- If the remote host is NOT reachable (no `studio-bridge serve` running, or port not forwarded), the CLI falls back to local mode within 3 seconds and prints a warning.
- The warning message includes instructions: run `studio-bridge serve` on the host, or use `--remote`.
- Outside a devcontainer (no env vars, no `/.dockerenv`), behavior is identical to pre-Phase-4 (local host/client detection).
- `--remote` flag takes precedence over auto-detection. If `--remote` is set, auto-detection is skipped even inside a devcontainer.
- `--local` flag disables auto-detection. Inside a devcontainer with `--local`, the CLI goes directly to local bind attempt.
- Empty string env vars (e.g., `REMOTE_CONTAINERS=""`) are treated as not set (falsy).
- **Unit test**: Set `REMOTE_CONTAINERS=true`, mock a reachable bridge host on `localhost:38741`. Call `connectAsync({})`. Verify it connects as a client (not a host).
- **Unit test**: Set `REMOTE_CONTAINERS=true`, no bridge host running. Call `connectAsync({})`. Verify it falls back to local mode within 3 seconds and logs a warning.
- **Unit test**: Set `REMOTE_CONTAINERS=true`, call `connectAsync({ remoteHost: 'otherhost:39000' })`. Verify it connects to `otherhost:39000` (explicit `--remote` overrides auto-detection).
- **Unit test**: Set `REMOTE_CONTAINERS=true`, call `connectAsync({ local: true })`. Verify it does NOT attempt remote connection.
- **Unit test**: No env vars set, no `/.dockerenv`. Call `connectAsync({})`. Verify no remote connection attempt (goes straight to local bind).

**Do NOT**:
- Use `host.docker.internal` as the default address. VS Code Dev Containers use port forwarding, so `localhost` is correct from inside the container.
- Create a separate "devcontainer client" class. The existing `bridge-client.ts` is used for all client connections.
- Make the auto-detection timeout an error. It is a warning with fallback.
- Run this task in parallel with Task 4.2. They both modify `bridge-connection.ts` and must be sequenced.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/04-split-server.md](../phases/04-split-server.md)
- Validation: [studio-bridge/plans/execution/validation/04-split-server.md](../validation/04-split-server.md)
- Tech spec: `studio-bridge/plans/tech-specs/05-split-server.md`
- Reference command pattern: `src/commands/sessions.ts` + `src/cli/commands/sessions-command.ts` (Task 1.7b)
- Shared utilities: `src/cli/resolve-session.ts`, `src/cli/format-output.ts`, `src/cli/types.ts` (Task 1.7a)
- Sequential chain: Task 4.2 -> Task 4.3 -> Task 6.5 (all modify `bridge-connection.ts`)
