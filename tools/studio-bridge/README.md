# @quenty/studio-bridge

WebSocket-based bridge for running Luau scripts in Roblox Studio.

## How It Works

```
┌─────────────┐    WebSocket     ┌──────────────────┐
│   Node.js   │◄───────────────►│  Studio Plugin    │
│   Server    │   ws://localhost │  (auto-injected)  │
│             │                  │                   │
│ 1. Start WS │                  │ 4. Connect + hello│
│ 2. Inject   │                  │ 5. Run script     │
│    plugin   │                  │ 6. Stream output  │
│ 3. Launch   │                  │ 7. scriptComplete │
│    Studio   │                  │                   │
└─────────────┘                  └──────────────────┘
```

1. Start WebSocket server on a random port
2. Build a temporary `.rbxmx` plugin with the port and session ID baked in
3. Write plugin to Studio's plugins folder, launch Studio
4. Plugin connects, handshakes with session ID
5. Server sends `execute` with Luau script, plugin runs it via `loadstring()` + `xpcall()`
6. Plugin streams `LogService` output back as batched messages
7. Plugin sends `scriptComplete` — server can send another `execute` or `shutdown`

The session ID (random UUID) prevents stale plugins from previous runs from interfering.

## CLI

```bash
# Run a script file
studio-bridge run test.lua

# Run inline script
studio-bridge exec 'print("hello world")'

# With a specific place file (builds a minimal place via rojo if omitted)
studio-bridge run test.lua --place build/test.rbxl

# Interactive terminal mode (keeps Studio alive between executions)
studio-bridge terminal

# Terminal mode with initial script
studio-bridge terminal --place build/test.rbxl --script init.lua

# Debug output
studio-bridge run test.lua --verbose
```

### Global Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--place` | `-p` | — | Path to a `.rbxl` place file (builds minimal place via rojo if omitted) |
| `--timeout` | — | `120000` | Timeout in milliseconds |
| `--verbose` | — | `false` | Show internal debug output |
| `--logs` / `--no-logs` | — | `true` | Show execution logs in spinner mode |

### Terminal Mode

Keeps Studio alive and provides an interactive REPL. Type Luau, see results, repeat — no re-launch between executions.

```
$ studio-bridge terminal --place build/test.rbxl
Studio connected.

────────────────────────────────────────────────────────
❯ print("hello")
────────────────────────────────────────────────────────
  ctrl+enter to run · ctrl+c to clear · .help for commands
```

| Key | Action |
|-----|--------|
| Enter | New line |
| Ctrl+Enter | Execute buffer |
| Ctrl+C | Clear buffer (exit if empty) |
| Ctrl+D | Exit |

| Command | Description |
|---------|-------------|
| `.help` | Show keybindings and commands |
| `.exit` | Exit terminal mode |
| `.run <file>` | Execute a Luau file |
| `.clear` | Clear the editor buffer |

## API

```typescript
import { StudioBridge } from '@quenty/studio-bridge';

const bridge = new StudioBridge({ placePath: './build/test.rbxl' });
await bridge.startAsync();

const result = await bridge.executeAsync({
  scriptContent: 'print("Hello from studio-bridge!")',
  timeoutMs: 90_000,
  onOutput: (level, body) => console.log(`[${level}] ${body}`),
});

console.log(result.success); // boolean
console.log(result.logs);    // all captured output, newline-separated

// Can call executeAsync() again without relaunching Studio
await bridge.stopAsync();
```

### `StudioBridgeServerOptions`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `placePath` | `string` | — | Path to `.rbxl` file (auto-builds via rojo if omitted) |
| `timeoutMs` | `number` | `120_000` | Default timeout for operations |
| `onPhase` | `(phase) => void` | — | Progress callback: `building`, `launching`, `connecting`, `executing`, `done` |
| `sessionId` | `string` | auto UUID | Session ID for concurrent isolation |

### `ExecuteOptions`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `scriptContent` | `string` | required | Luau source code to execute |
| `timeoutMs` | `number` | inherited | Timeout for this execution |
| `onOutput` | `(level, body) => void` | — | Called for each log message |

### `StudioBridgeResult`

| Field | Type | Description |
|-------|------|-------------|
| `success` | `boolean` | `true` if the script ran without errors |
| `logs` | `string` | All captured output, newline-separated |

## WebSocket Protocol

All messages are JSON: `{ "type": string, "payload": object }`.

**Plugin to Server:**

| Type | Payload | Description |
|------|---------|-------------|
| `hello` | `{ sessionId }` | Handshake |
| `output` | `{ messages: [{ level, body }] }` | Batched log output |
| `scriptComplete` | `{ success, error? }` | Script finished |

Output levels: `"Print"`, `"Info"`, `"Warning"`, `"Error"` (matches `Enum.MessageType`).

**Server to Plugin:**

| Type | Payload | Description |
|------|---------|-------------|
| `welcome` | `{ sessionId }` | Handshake accepted |
| `execute` | `{ script }` | Luau script to run |
| `shutdown` | `{}` | Disconnect |

## Testing

```bash
pnpm test              # Unit tests (no Studio needed)
pnpm test:watch        # Watch mode
pnpm test:integration  # End-to-end (requires Studio)
```

| Layer | What it tests | Studio? |
|-------|--------------|---------|
| Unit (`pnpm test`) | Protocol, XML builder, template substitution, path resolution, WebSocket lifecycle | No |
| Integration (`pnpm test:integration`) | Full pipeline: rojo build, plugin injection, Studio launch, output capture | Yes |

## Platform Support

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |

## Future Plans

- **StudioTestService integration** — Use `ExecuteRunModeAsync()` / `EndTest()` for better isolation vs. `loadstring()`
- **Structured test results** — Protocol extension for typed result messages instead of log parsing
