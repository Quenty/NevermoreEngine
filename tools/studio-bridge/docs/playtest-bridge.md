# The planted playtest bridge

With Studio's **Load user plugins on playtest** off, the studio-bridge plugin never loads into a playtest. So `startPlaytest` plants the same client (`templates/studio-bridge-plugin/src/Shared/StudioBridgeClient.lua`) into the edit place's ServerScriptService. The playtest copies the edit place, so the client starts in the playtest's server as an ordinary Script and connects as its server session. With the setting on, nothing is planted and the plugin is the server session.

## What an ordinary playtest Script can do

These limits shape the design. They were measured in a Studio playtest server:

| Capability | Result |
|---|---|
| WebSocket to the bridge on localhost (`CreateWebStreamClient`) | Works, even with Allow HTTP Requests off |
| `HttpService:GetAsync` to localhost | Refused, so the port comes from the StudioTestService test args instead of a scan |
| `loadstring` | Off. `LoadStringEnabled` isn't scriptable, not even from a plugin |
| Setting `ModuleScript.Source` | Needs the `PluginOrOpenCloud` capability |
| `SerializationService` | `GetService` returns `nil` |

So the planted client can't compile code. The edit session compiles everything ahead of time: each action, and any script `playtest run` will send, becomes a ModuleScript returning its function and its own source text. The router finds a source by its exact text (`PrecompiledSources.lua`, built by `src/plugin/playtest-bridge.ts`). New code sent to a planted session fails and asks for the setting. Privileged compiling, for example through Studio's MCP `execute_luau`, would plug in at `ActionRouter:SetCompiler`.

A precompiled source that fails to load is skipped, which would hide its compile error. So `startPlaytest` compiles every one in the edit session before planting.

`LogService.MessageOut` fires a frame or two after a `print` in a playtest server, later than in a plugin. That's why `execute.lua` waits several frames before it stops capturing output.
