# The planted playtest bridge

Studio only loads plugins into a playtest when **Load user plugins on playtest** is on. When it's off, `studio-bridge` still needs a session inside the playtest, so `playtest start` plants a copy of the plugin into the place before the playtest begins.

With the setting on, nothing is planted: the plugin itself provides the playtest's sessions.

## What gets planted

| Where | As | Becomes |
|---|---|---|
| `ServerScriptService` | Script | the playtest's **server** session |
| `StarterPlayerScripts` (play mode only) | LocalScript | each player's **client** session |

Both are copies of the plugin's single entry script, `plugins/studio-bridge-plugin/src/init.server.lua`, and its modules. The playtest copies the edit place, so the copies come along and run as ordinary game scripts.

Because the edit plugin plants itself, a playtest always runs the plugin version installed in Edit. `playtest start` therefore requires the current plugin.

## How a copy knows to run

The entry script checks for the `plugin` global, which only a plugin has. Without it, the script is a planted copy, and it starts only if the playtest's StudioTestService arguments name the playtest it was planted for.

A copy saved into a place, or left behind by an earlier playtest, never starts.

## What a playtest script can't do

A planted copy runs with game-script permissions, measured in a Studio playtest:

| Capability | In a playtest script |
|---|---|
| WebSocket to localhost (`CreateWebStreamClient`) | Works, even with HTTP requests off |
| `HttpService` to localhost | Refused. The bridge port comes from the StudioTestService arguments instead |
| `loadstring` | Off, and a plugin can't turn it on |
| Setting `ModuleScript.Source` | Refused |
| `SerializationService` | Unavailable |

So a planted copy can't compile code.

## Running code without compiling

Everything a planted copy runs must exist before the playtest starts.

- **Pushed actions.** Elsewhere, the plugin installs each action the CLI pushes as a ModuleScript tagged with its content hash. `playtest start` plants copies of those modules, and the planted copy requires the one whose name and hash match.
- **`playtest run` scripts** are compiled ahead of time into ModuleScripts that the copy looks up by their exact source text. `playtest start` loads each one in Edit first, so a compile error shows there instead of being skipped silently.
- **Anything else** sent to a planted session fails with a message to turn on the setting.

## Updates during a playtest

If the CLI pushes a newer action while a playtest runs, for example after a rebuild, the planted copy can't install it. It keeps answering with the version it has and marks it outdated, and the CLI warns:

```
This playtest runs an older 'explorer sample'; restart the playtest to update it
```

## Gotcha

`LogService.MessageOut` reaches a playtest server a frame or two after the `print`, later than in a plugin. Code that captures output must wait a few frames before it stops listening.
