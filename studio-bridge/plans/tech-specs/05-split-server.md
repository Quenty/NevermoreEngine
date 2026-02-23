# Split Server Mode: Technical Specification

This document describes the split-server architecture for running studio-bridge across a devcontainer boundary. It is the companion document referenced from `00-overview.md` section 7.4 ("Split-server mode, devcontainer port forwarding").

## 1. Consumer Invariant

**The split server is an operational concern, not an API concern.** Consumer code (commands, MCP tools, terminal) never imports from server-specific modules. They use `BridgeConnection` which auto-discovers the host regardless of how it was started.

The `serve` command is just one way to start a bridge host. From a consumer's perspective:

- `BridgeConnection` works identically whether the host is implicit (first CLI process) or explicit (`studio-bridge serve`)
- No code outside `src/bridge/internal/` knows or cares whether the host is a dedicated process
- The same `BridgeSession` methods produce the same results regardless of how the host was started
- Session multiplicity is transparent: a Studio instance in Play mode produces 3 sessions (edit/client/server contexts), but this is the same whether the host is local or split

This is a direct consequence of the API boundary described in `00-overview.md` section 1.1. Any change that would require a consumer to be aware of whether the host is implicit or explicit is a design violation.

## 2. Problem

AI coding tools (Claude Code, Cursor, GitHub Copilot) increasingly run inside devcontainers -- Docker-based environments with full Linux toolchains. Roblox Studio only runs on Windows and macOS. This creates a gap:

- The CLI, MCP server, and build tools run inside the devcontainer
- Studio runs on the host OS
- There is no way for the devcontainer to communicate with Studio

The default bridge host behavior (first CLI process to bind port 38741 becomes the host) does not work when the CLI and Studio are on different machines. The CLI inside the devcontainer cannot launch Studio, inject plugins, or accept WebSocket connections from plugins running on the host OS.

## 3. Architecture

Split-server mode separates the bridge host and CLI into two processes on two machines. The bridge host runs on the machine with Studio; the CLI runs in the devcontainer. Port forwarding bridges the gap.

### Topology: implicit host vs. explicit host

```
Option A: Implicit host (default -- single machine)
┌─────────────────────────────┐
│ CLI process (first started) │
│ ┌─────────────┐             │
│ │ Bridge Host  │<── Studio plugins connect via /plugin
│ └─────────────┘             │
│ + CLI commands              │
└─────────────────────────────┘

Option B: Explicit host (studio-bridge serve -- devcontainer workflow)
┌─────────────────────────────┐
│ studio-bridge serve         │
│ ┌─────────────┐             │
│ │ Bridge Host  │<── Studio plugins connect via /plugin
│ └─────────────┘             │
└──────────────┬──────────────┘
               │ port 38741 (forwarded into container)
┌──────────────┴──────────────┐
│ CLI process (client mode)   │
│ CLI commands, MCP, terminal │
└─────────────────────────────┘
```

In both cases, CLI commands use `BridgeConnection` identically. The consumer code is the same. The only difference is where the bridge host process runs and how it was started.

### Detailed devcontainer layout

```
┌──────────────────────────────────┐      ┌────────────────────────────────────┐
│          Devcontainer            │      │           Host OS                   │
│                                  │      │                                     │
│  ┌────────────────────────┐      │      │  ┌──────────────────────────────┐   │
│  │  studio-bridge exec    │      │      │  │   studio-bridge serve        │   │
│  │  studio-bridge mcp     │      │      │  │   (bridge host on 38741)     │   │
│  │  nevermore test         │      │ TCP  │  │                              │   │
│  │                         ├──────┼──────┤  │   Bridge Host (internal)     │   │
│  │  (bridge client)        │      │      │  │   - plugin connections       │   │
│  └────────────────────────┘      │      │  │   - client connections        │   │
│                                  │      │  │   - session tracking          │   │
│                                  │      │  │                              │   │
│                                  │      │  │   WebSocket <-> Plugin(s)    │   │
│                                  │      │  └──────────┬───────────────────┘   │
│                                  │      │             │                       │
│                                  │      │    ┌────────v──────────┐            │
│                                  │      │    │  Roblox Studio    │            │
│                                  │      │    │  + Persistent     │            │
│                                  │      │    │    Plugin          │            │
│                                  │      │    └───────────────────┘            │
│                                  │      │                                     │
└──────────────────────────────────┘      └────────────────────────────────────┘
                    ^                                        ^
                    │         Port forwarding (38741)         │
                    └────────────────────────────────────────┘
```

**Bridge Host**: Runs on the machine with Studio. This is the same `bridge-host.ts` from `src/bridge/internal/` -- the `serve` command just instantiates and runs it. Hosts the WebSocket server, manages plugin connections, handles the session tracker. A single Studio instance may produce 1-3 sessions (one per context: `edit`, and optionally `client`/`server` during Play mode), all grouped by `instanceId`.

**Bridge Client**: Runs in the devcontainer. This is the same `bridge-client.ts` from `src/bridge/internal/` -- `BridgeConnection.connectAsync()` uses it automatically when a host is already running (or when `--remote` is specified). Sends commands to the host over a relayed WebSocket connection. Formats output for the user.

## 4. `studio-bridge serve` Command

The `serve` command is a thin CLI wrapper that calls into `src/bridge/internal/bridge-host.ts` directly. It starts a headless bridge host (no terminal UI) that stays alive indefinitely. This is the same bridge host that any CLI process creates when it is the first to bind port 38741 -- the only difference is that `serve` always becomes the host (never a client) and never exits on idle.

### CLI interface

```
studio-bridge serve [options]

Options:
  --port <number>     Port to listen on (default: 38741)
  --log-level <level> Log verbosity: silent, error, warn, info, debug (default: info)
  --json              Print structured status to stdout on startup and on events
  --timeout <ms>      Auto-shutdown after idle period with no connections (default: none)
```

### How it differs from the implicit host

| Aspect | Implicit host (first CLI) | Explicit host (`studio-bridge serve`) |
|--------|---------------------------|--------------------------------------|
| How it starts | `BridgeConnection.connectAsync()` binds port, process happened to be first | User runs `studio-bridge serve` explicitly |
| Idle behavior | Exits after 5s grace period when no clients/commands | Stays alive indefinitely (or until `--timeout`) |
| Terminal UI | Yes (if started via `terminal`), No (if `exec`/`run`) | No (headless, logs to stdout) |
| Hand-off on exit | Transfers to a connected client | Transfers to a connected client (same protocol) |
| Port contention | Falls back to client mode if port taken | Errors with clear message if port taken |
| Signal handling | Standard CLI cleanup | SIGTERM/SIGINT trigger graceful shutdown + hand-off |

### When to use `studio-bridge serve`

- **Devcontainer workflow**: Studio runs on the host OS, CLI runs in a container. Run `serve` on the host so the container CLI can connect.
- **CI environments**: A long-running bridge host that multiple CI jobs connect to as clients.
- **Shared development server**: A team member runs `serve` on a shared machine; others connect their CLIs as clients.
- **Long-running daemon**: When you want the bridge host to outlive any individual CLI session.

For local single-machine development, `serve` is unnecessary. The first CLI process becomes the host automatically.

### Implementation

The `serve` command is just `BridgeConnection.connectAsync({ keepAlive: true })` with signal handling and status logging:

```typescript
// src/commands/serve.ts (the command definition)
export const serveCommand: CommandDefinition<ServeInput, CommandResult<ServeOutput>> = {
  name: 'serve',
  description: 'Start a dedicated bridge host process',
  requiresSession: false,  // serve IS the host, it doesn't need a session

  handler: async (input, context) => {
    // BridgeConnection with keepAlive prevents idle shutdown.
    // The bridge host is created internally by bridge-connection.ts
    // via bridge-host.ts from src/bridge/internal/.
    const connection = await BridgeConnection.connectAsync({
      port: input.port,
      keepAlive: true,
    });

    // Log status
    const sessions = await connection.listSessionsAsync();
    return {
      data: { port: input.port ?? 38741, sessions },
      summary: `Bridge host listening on port ${input.port ?? 38741}`,
    };
  },
};
```

The actual bridge host logic (WebSocket server, plugin management, client multiplexing, session tracking) all lives in `src/bridge/internal/bridge-host.ts`. The `serve` command does not duplicate or extend that logic.

### Daemon lifecycle

1. **Start**: `BridgeConnection.connectAsync({ keepAlive: true })` binds the port and creates a bridge host
2. **Listen**: Accept connections from plugins (`/plugin`) and CLI clients (`/client`)
3. **Run**: Route commands between clients and plugins (standard bridge host behavior)
4. **Status**: If `--json`, print session connect/disconnect events as JSON lines to stdout
5. **Stop**: On SIGTERM/SIGINT, run `disconnectAsync()` which triggers the hand-off protocol (transfer to a connected client, or shut down cleanly)

### Error on port contention

Unlike the implicit host (which falls back to client mode on EADDRINUSE), `serve` fails with a clear error if the port is already in use:

```
Error: Port 38741 is already in use.
A bridge host is already running. Connect as a client with any studio-bridge command,
or use --port to start on a different port.
```

This is intentional: `serve` is an explicit request to BE the host. Silent fallback to client mode would be confusing.

## 5. File Layout

The split server has minimal footprint. It follows the same pattern as every other command: one file in `src/commands/`, using existing infrastructure from `src/bridge/internal/`.

```
src/
  commands/
    serve.ts                          serve command definition (like any other command)
  bridge/
    internal/
      bridge-host.ts                  THE bridge host implementation (already exists from Phase 1)
      bridge-client.ts                THE bridge client implementation (already exists from Phase 1)
      environment-detection.ts        isDevcontainer(), getDefaultRemoteHost()
    bridge-connection.ts              Handles remoteHost option, devcontainer auto-detection
```

There is no `src/server/` directory for split-server-specific code. The bridge host itself lives in `src/bridge/internal/`. The `serve` command just instantiates and runs it. Environment detection lives alongside the other bridge internals because it is part of the connection logic.

### Why no separate `src/server/` directory

The split server does not introduce new abstractions. It is the same bridge host, started a different way. The concerns that might justify a separate directory -- daemonization, PID files, log rotation, auth token management -- are either unnecessary or handled by existing mechanisms:

- **Daemonization**: Not needed. Run `serve` in a terminal, tmux, systemd, or Docker. The command stays in the foreground.
- **PID files**: Not needed. Port binding IS the lock. Only one process can bind 38741.
- **Log rotation**: Not needed. Stdout goes wherever the user directs it (`serve > bridge.log 2>&1`).
- **Auth tokens**: Not needed for the initial implementation. All connections are localhost or port-forwarded localhost. The bridge host validates plugin connections via session ID (unguessable UUIDv4) and client connections via the `/client` WebSocket path. If auth tokens become necessary later, they would live in `src/bridge/internal/` as part of the transport layer -- still not a separate directory.

## 6. Client Connection (CLI in Devcontainer)

### `--remote` CLI flag

Users can explicitly specify a remote bridge host:

```bash
# Force remote mode -- connect to bridge host at the specified address
studio-bridge exec --remote localhost:38741 'print("hi")'

# Force local mode -- disable auto-detection, always try to become host
studio-bridge exec --local 'print("hi")'
```

The `--remote` flag sets `remoteHost` on `BridgeConnectionOptions`. When set, `BridgeConnection.connectAsync()` skips the local port-bind attempt and connects directly as a client:

```typescript
// In BridgeConnectionOptions (from src/bridge/types.ts)
export interface BridgeConnectionOptions {
  port?: number;
  timeoutMs?: number;
  keepAlive?: boolean;
  remoteHost?: string;  // e.g., 'localhost:38741' -- skip local bind, connect as client
}
```

### Devcontainer auto-detection

When the CLI detects it is running inside a devcontainer, it automatically tries connecting to a remote bridge host before falling back to local mode:

```typescript
// src/bridge/internal/environment-detection.ts

export function isDevcontainer(): boolean {
  return !!(
    process.env.REMOTE_CONTAINERS ||
    process.env.CODESPACES ||
    process.env.CONTAINER ||
    existsSync('/.dockerenv')
  );
}

export function getDefaultRemoteHost(): string | null {
  if (isDevcontainer()) {
    return `localhost:${DEFAULT_BRIDGE_PORT}`;
  }
  return null;
}
```

### Decision flow in `BridgeConnection.connectAsync()`

```
connectAsync() called
  |
  +-- remoteHost option provided?
  |   YES -> connect to host at remoteHost as client
  |
  +-- isDevcontainer()?
  |   YES -> try connecting to localhost:38741
  |          +-- success -> use as client (bridge host is on host OS, port-forwarded)
  |          +-- failure -> warn, fall back to local mode
  |
  +-- NO -> try binding port 38741
       +-- success -> become bridge host
       +-- EADDRINUSE -> connect as client to existing host
```

This decision flow is entirely within `BridgeConnection`. Consumer code never sees it. The same `BridgeSession` methods work regardless of which path was taken.

## 7. Port Forwarding

### VS Code Dev Containers

VS Code automatically forwards ports from the host to the devcontainer when it detects a listening socket. However, port 38741 may not be auto-detected since the daemon starts independently.

**Recommended configuration** in `.devcontainer/devcontainer.json`:

```json
{
  "forwardPorts": [38741],
  "portsAttributes": {
    "38741": {
      "label": "Studio Bridge",
      "onAutoForward": "silent"
    }
  }
}
```

### GitHub Codespaces

Codespaces forwards all ports by default. The bridge host on the host is accessible from within the Codespace at `localhost:38741` when port forwarding is configured.

**Note**: GitHub Codespaces runs in the cloud, not on the user's local machine. The user must run a tunnel or use VS Code's Remote SSH to bridge between Codespaces and their local machine where Studio runs. This is a more advanced setup documented in the migration guide.

### Docker Compose

For Docker Compose-based dev environments:

```yaml
services:
  dev:
    ports:
      - "38741:38741"  # Studio Bridge host
```

### Port direction

Port forwarding goes **from host into container**:
- Bridge host listens on host port 38741
- Container accesses it at `localhost:38741` (forwarded)
- Plugin connects to bridge host on localhost (no forwarding needed, same machine)

## 8. Unified Interface

The bridge host pattern described in `00-overview.md` already handles all the complexity. The `BridgeConnection` and `BridgeSession` classes work identically regardless of how the host was started. There is no separate "daemon session" or "remote session" type.

```typescript
// This code is identical in all scenarios:
// - Implicit host (first CLI becomes host)
// - Explicit host (studio-bridge serve)
// - Local (same machine)
// - Remote (devcontainer with port forwarding)

const bridge = await BridgeConnection.connectAsync();
const session = await bridge.waitForSessionAsync();
const result = await session.execAsync({ scriptContent: 'print("hello")' });
console.log(result.output);
```

In split-server mode, `disconnectAsync()` on a client closes the client connection but does NOT stop the bridge host or kill Studio. The bridge host continues serving other clients and maintaining plugin connections. This is the same behavior as any bridge client disconnecting -- the host is independent.

## 9. Security

### All connections are localhost

All connections are localhost-only (or port-forwarded localhost). TLS adds complexity without security benefit when both endpoints are on the same machine or connected via secure port forwarding (SSH tunnel, VS Code forwarding).

### Plugin authentication

Plugin connections are validated by session ID in the WebSocket path -- the same mechanism as single-process mode. Session IDs are UUIDv4 (128 bits of entropy), unguessable by other processes.

### Client authentication

In the initial implementation, bridge client connections on `/client` are unauthenticated. This is acceptable because:
- All connections are localhost (or port-forwarded localhost through a secure tunnel)
- The threat model is preventing accidental cross-user access, not sandboxing within a single user session
- Any process running as the same user could already read the plugin source and discover the port

If a future requirement demands non-localhost connections or stricter isolation, a bearer token mechanism can be added to the bridge host's client connection handler in `src/bridge/internal/bridge-host.ts`. This would be an internal change -- consumers using `BridgeConnection` would not be affected.

## 10. Limitations and Future Work

- **One host per port**: Only one bridge host can bind a given port. Use `--port` to run multiple hosts on different ports.
- **No multi-user support**: The bridge host serves one user's Studio sessions. Shared machines with multiple users each need their own host on different ports.
- **No remote-over-internet**: All connections are localhost or port-forwarded localhost. Direct remote connections would require TLS, auth improvements, and NAT traversal.
- **Codespaces cloud gap**: Codespaces runs in the cloud, not on the user's machine. Bridging to local Studio requires an SSH tunnel or VS Code's built-in port forwarding from local to Codespace. This is documented but not automated.
- **No daemonization**: `serve` runs in the foreground. Use tmux, systemd, or Docker to run it as a background daemon if needed. A `--detach` flag could be added later if there is demand.
