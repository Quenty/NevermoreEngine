# Studio Bridge: Persistent Sessions Migration Guide

Studio Bridge v0.7 introduces persistent sessions -- the plugin stays running in Roblox Studio and maintains a WebSocket connection to a bridge server. This replaces the one-shot launch-execute-exit workflow with a persistent connection that supports multiple commands, multiple Studio instances, and AI agent integration via MCP.

## 1. Install the Persistent Plugin

The persistent plugin runs inside Roblox Studio and auto-discovers the bridge server on port 38741. No manual port configuration is needed.

```bash
# Install the plugin into your local Roblox Studio plugins folder
studio-bridge install-plugin

# Verify: open Studio, then check for connected sessions
studio-bridge sessions

# Remove the plugin later if needed
studio-bridge uninstall-plugin
```

The plugin is copied to your OS plugins folder:
- **macOS**: `~/Library/Application Support/Roblox/Plugins/`
- **Windows**: `%LOCALAPPDATA%/Roblox/Plugins/`

After installing, restart any open Studio instances. The plugin connects automatically when Studio starts.

## 2. New CLI Commands

All session-targeting commands accept `--session <id>`, `--instance <id>`, and `--context <edit|client|server>`. These are optional when only one Studio instance is connected. When multiple instances are connected, use `--session` or `--instance` to disambiguate.

### sessions -- list connected Studio instances

```bash
studio-bridge sessions
studio-bridge sessions --json
```

### state -- query Studio mode and place info

```bash
studio-bridge state
studio-bridge state --session abc123
```

### screenshot -- capture the Studio viewport

```bash
studio-bridge screenshot --output viewport.png
studio-bridge screenshot --base64              # print raw base64 to stdout
studio-bridge screenshot --json                # JSON with dimensions and data
```

### logs -- retrieve output log history

```bash
studio-bridge logs                             # last 50 entries (default)
studio-bridge logs --tail 100                  # last 100 entries
studio-bridge logs --head 20                   # oldest 20 entries
studio-bridge logs --level Error,Warning       # filter by level
studio-bridge logs --all                       # include internal messages
studio-bridge logs --follow                    # stream new entries (planned)
```

### query -- inspect the DataModel tree

```bash
studio-bridge query Workspace
studio-bridge query Workspace.SpawnLocation --properties
studio-bridge query game.ReplicatedStorage --children
studio-bridge query Workspace --descendants --depth 3
studio-bridge query Workspace.Part --attributes
```

### serve -- start a standalone bridge server

```bash
studio-bridge serve                            # listen on default port 38741
studio-bridge serve --port 9000                # custom port
```

Runs a long-lived bridge host. Use this for split-server mode (see section 3).

### terminal -- interactive REPL with dot-commands

```bash
studio-bridge terminal
studio-bridge terminal --script init.lua       # run a file on connect
studio-bridge terminal --script-text 'print("ready")'
```

Inside terminal mode, dot-commands provide quick access to bridge features:

| Command | Description |
|---------|-------------|
| `.sessions` | List connected sessions |
| `.connect <id>` | Switch to a session |
| `.disconnect` | Detach from the active session |
| `.state` | Query Studio state |
| `.screenshot` | Capture a screenshot |
| `.logs` | Show recent log entries |
| `.query <path>` | Query the DataModel |
| `.help` | Show all commands |
| `.exit` | Exit terminal mode |

### exec and run -- session targeting

The existing `exec` and `run` commands now support persistent sessions:

```bash
# Persistent session (fast, no Studio launch)
studio-bridge exec 'print(workspace:GetChildren())' --session abc123

# Legacy one-shot (launches Studio, executes, exits)
studio-bridge exec 'print("hello")'
```

When `--session`, `--instance`, or `--context` is passed, the command uses the persistent bridge connection. Otherwise it falls back to the original one-shot behavior.

## 3. Split-Server Mode (Devcontainers)

When developing inside Docker, a devcontainer, or GitHub Codespaces, the CLI cannot reach Roblox Studio directly. Run the bridge server on the host OS and connect from inside the container.

**On the host OS** (where Studio runs):

```bash
studio-bridge serve
```

**Inside the container:**

```bash
# Automatic detection works if port 38741 is forwarded
studio-bridge sessions

# Or specify the host explicitly
studio-bridge sessions --remote host.docker.internal:38741
studio-bridge exec 'print("hello")' --remote localhost:38741
```

Port 38741 must be forwarded from the container to the host. In VS Code devcontainers, add to `devcontainer.json`:

```json
{
  "forwardPorts": [38741]
}
```

Use `--local` to skip devcontainer auto-detection and force local mode.

## 4. MCP Integration for AI Agents

Studio Bridge exposes its commands as MCP tools for AI agents like Claude Code.

### Configuration

Add to `.mcp.json` or your Claude Code MCP config:

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "studio-bridge",
      "args": ["mcp"]
    }
  }
}
```

For devcontainer environments, pass `--remote`:

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "studio-bridge",
      "args": ["mcp", "--remote", "localhost:38741"]
    }
  }
}
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `studio_sessions` | List active Studio sessions |
| `studio_state` | Query Studio mode and place info |
| `studio_screenshot` | Capture a viewport screenshot (returns PNG image) |
| `studio_logs` | Retrieve buffered log history |
| `studio_query` | Query the DataModel instance tree |
| `studio_exec` | Execute inline Luau code |

All tools except `studio_sessions` accept optional `sessionId` and `context` parameters for targeting specific sessions.
