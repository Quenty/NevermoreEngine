# @quenty/studio-bridge

WebSocket-based bridge for running Luau scripts in Roblox Studio. Replaces the unmaintained [`run-in-roblox`](https://github.com/LPGhatguy/run-in-roblox) tool with a modern, bidirectional communication channel.

## Why

`run-in-roblox` uses a simple HTTP polling model where a Studio plugin POSTs log batches to a local HTTP server. It's unmaintained and fragile. `studio-bridge` uses **WebSockets** for persistent bidirectional communication, enabling:

- Real-time output streaming (no polling delay)
- Reliable script completion detection
- Future capability: sending commands to a running Studio session (e.g., re-running tests without relaunching)

## How It Works

```
┌─────────────┐    WebSocket     ┌──────────────────┐
│   Node.js   │◄───────────────►│  Studio Plugin    │
│   Server    │   ws://localhost │  (auto-injected)  │
│             │                  │                   │
│ 1. Start WS │                  │ 4. Connect + hello│
│ 2. Inject   │                  │ 5. Stream output  │
│    plugin   │                  │ 6. Run script     │
│ 3. Launch   │                  │ 7. scriptComplete │
│    Studio   │                  │                   │
└─────────────┘                  └──────────────────┘
```

### Execution Flow

1. **Start WebSocket server** on port 0 (OS assigns a free port)
2. **Generate a session ID** (UUID) for handshake validation
3. **Build plugin `.rbxmx`** from the Lua template, substituting `{{PORT}}`, `{{SESSION_ID}}`, and `{{SCRIPT}}`
4. **Write plugin** to Studio's plugins folder as `studio-bridge-{sessionId}.rbxmx`
5. **Launch Studio** with the target `.rbxl` place file
6. **Plugin connects** via WebSocket and sends `hello` with the session ID
7. **Server validates** the session ID and sends `welcome`
8. **Plugin executes** the embedded script via `loadstring()` + `xpcall()`
9. **Plugin streams** LogService output back as batched `output` messages
10. **Plugin sends `scriptComplete`** when the script finishes (success or error)
11. **Server cleans up**: sends `shutdown`, kills Studio, deletes plugin file, closes server

### Plugin Injection

The plugin is a temporary `.rbxmx` file written to Studio's plugins folder. Studio automatically loads plugins from this folder on startup. The plugin:

- Only runs inside Studio (`RunService:IsStudio()` guard)
- Connects to the local WebSocket server using `HttpService:CreateWebStreamClient()`
- Hooks `LogService.MessageOut` for output capture with batching (flushes on Heartbeat)
- Executes the embedded script via `loadstring()` in a protected call (`xpcall`)
- Reports back success/failure, then cleans up on `shutdown`

The plugin file is deleted after execution completes (or on error).

### Studio Process Management

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |

On Windows, Studio is found by scanning version folders under `%LOCALAPPDATA%\Roblox\Versions\`. Process cleanup uses `taskkill /F /T` on Windows for reliable tree-kill.

## CLI Usage

```bash
# Run a script file
studio-bridge --script test.lua

# Run inline script
studio-bridge --script-text 'print("hello world")'

# With a specific place file
studio-bridge --place build/test.rbxl --script test.lua

# Show internal debug output
studio-bridge --verbose --script test.lua
```

### Example Output

```
Building place... done
Launching Studio... done
Waiting for plugin... connected
Executing script...

Hello from integration test
Test passed

Script completed successfully. (14.2s)
```

On error:
```
Launching Studio... done
Waiting for plugin... connected
Executing script...

[Error] loadstring failed: [string "Hello"]:1: Incomplete statement: expected assignment or a function call

Script failed. (8.4s)
```

Use `--verbose` to see internal debug messages (WebSocket lifecycle, plugin injection paths, etc.) for troubleshooting.

## API

```typescript
import { StudioBridge } from '@quenty/studio-bridge';

const result = await StudioBridge.executeAsync({
  // Path to the .rbxl place file (e.g., built by rojo)
  placePath: './build/test.rbxl',

  // Luau script to execute inside Studio
  scriptContent: 'print("Hello from studio-bridge!")',

  // Timeout in ms (default: 120_000)
  timeoutMs: 90_000,

  // Optional: callback for real-time output streaming
  onOutput: (level, body) => {
    console.log(`[${level}] ${body}`);
  },
});

console.log(result.success); // boolean
console.log(result.logs);    // string — all captured output joined by newlines
```

### `StudioBridgeOptions`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `placePath` | `string` | — | Absolute or relative path to the `.rbxl` file (auto-builds via rojo if omitted) |
| `scriptContent` | `string` | required | Luau source code to execute |
| `timeoutMs` | `number` | `120_000` | Maximum time to wait for script completion |
| `onOutput` | `(level, body) => void` | — | Called for each log message as it arrives |
| `onPhase` | `(phase) => void` | — | Called at progress transitions: `building`, `launching`, `connecting`, `executing`, `done` |

### `StudioBridgeResult`

| Field | Type | Description |
|-------|------|-------------|
| `success` | `boolean` | `true` if the script ran without errors |
| `logs` | `string` | All captured output, newline-separated |

### Lower-level exports

For advanced usage or testing, individual modules are also exported:

```typescript
import {
  buildRbxmx,
  findStudioPathAsync,
  findPluginsFolder,
  launchStudioAsync,
  injectPluginAsync,
  substituteTemplate,
  escapeLuaString,
  encodeMessage,
  decodePluginMessage,
} from '@quenty/studio-bridge';
```

## WebSocket Message Protocol

All messages are JSON: `{ "type": string, "payload": object }`.

### Plugin to Server

| Type | Payload | Description |
|------|---------|-------------|
| `hello` | `{ sessionId: string }` | Handshake — confirms correct server |
| `output` | `{ messages: [{ level, body }] }` | Batched log output |
| `scriptComplete` | `{ success: boolean, error?: string }` | Script finished |

Output levels match Roblox's `Enum.MessageType`: `"Print"`, `"Info"`, `"Warning"`, `"Error"`.

### Server to Plugin

| Type | Payload | Description |
|------|---------|-------------|
| `welcome` | `{ sessionId: string }` | Handshake accepted |
| `execute` | `{ script: string }` | Send Luau script to run |
| `shutdown` | `{}` | Tell plugin to disconnect |

## Testing

```bash
# Unit tests (no Studio needed)
pnpm test

# Watch mode
pnpm test:watch

# Integration test (requires rojo + Studio installed)
pnpm test:integration
```

### Test Layers

| Layer | Command | What it tests | Studio needed? |
|-------|---------|--------------|----------------|
| Build | `pnpm build` | TypeScript compiles | No |
| Unit | `pnpm test` | Protocol, XML builder, template substitution, path resolution | No |
| WS smoke | Included in `pnpm test` | Full WebSocket lifecycle with simulated plugin client | No |
| Integration | `pnpm test:integration` | End-to-end: rojo build, plugin injection, Studio launch, output capture | Yes |

The **inner loop** (edit, build, unit + WS smoke tests) runs in seconds and covers most logic. The **outer loop** (integration with Studio) validates the Luau plugin and process management.

## Integration with nevermore-cli

This package exposes a programmatic API. The planned integration point in `nevermore-cli` is `tools/nevermore-cli/src/utils/testing/runner/test-runner.ts`, where `runSingleLocalTestAsync` currently calls `execa('run-in-roblox', ...)`. The replacement:

```typescript
// Before (run-in-roblox):
const result = await execa('run-in-roblox', ['--place', rbxlPath, '--script', scriptPath], { ... });

// After (studio-bridge):
import { StudioBridge } from '@quenty/studio-bridge';
const result = await StudioBridge.executeAsync({
  placePath: rbxlPath,
  scriptContent: await fs.readFile(scriptPath, 'utf-8'),
  timeoutMs,
});
```

The return type `{ success: boolean, logs: string }` is already compatible with `SingleTestResult`.

## Architecture Notes

### Why WebSockets over HTTP polling?

- **Lower latency**: output appears in real-time, not batched on a polling interval
- **Bidirectional**: the server can send commands to the plugin (execute, shutdown), not just receive
- **Connection awareness**: the server knows immediately when the plugin disconnects
- **Simpler protocol**: no need for the plugin to implement HTTP client request/response cycles

### Why inject a plugin file vs. embedding in the place?

Plugin injection (writing `.rbxmx` to the plugins folder) is the same approach `run-in-roblox` uses. It works because Studio automatically loads all plugins on startup. The alternative — embedding a Script in the place's DataModel — would require modifying the rojo build, which is more invasive and harder to clean up if something goes wrong.

### Session ID validation

Each bridge instance generates a random UUID session ID. The plugin must send this ID in its `hello` message. This prevents stale plugins from previous sessions (that weren't cleaned up) from interfering with the current session.

### Output batching

The Luau plugin collects LogService output into a buffer and flushes on every `Heartbeat` frame. This is similar to `run-in-roblox`'s 0.1s batching approach but tied to the frame loop instead of a timer, ensuring output is flushed consistently even under heavy load.

## Future Plans

### Persistent Studio sessions (no re-launch)

The WebSocket protocol is designed to support keeping Studio running between test executions. The `execute` message type allows sending new scripts to a running plugin without relaunching Studio. Combined with Rojo live sync, this enables:

1. **Edit code** in your editor
2. **Rojo syncs** changes to the running Studio instance
3. **Bridge sends `execute`** with the test script
4. **Plugin runs** the test and streams results back
5. **No Studio restart needed** — saves 10-15 seconds per iteration

### StudioTestService integration

Roblox's `StudioTestService` provides `ExecuteRunModeAsync()` and `EndTest()` APIs for running tests in an isolated server context. A future version could use these instead of `loadstring()` for better isolation and closer parity with production behavior.

### Structured test results

Currently, test results are determined by parsing log output (looking for Jest failure patterns and Luau stack traces). A future protocol extension could add structured result messages:

```json
{ "type": "testResult", "payload": { "suite": "...", "passed": 10, "failed": 1, "errors": [...] } }
```

This would eliminate fragile log parsing and enable richer test reporting.

### Multiple concurrent sessions

The session ID mechanism already supports running multiple bridge instances simultaneously (e.g., for parallel test execution). Each instance gets its own port, session ID, and plugin file.
