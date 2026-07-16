## NevermoreCliManifest

<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Manifest of nevermore CLI-injected deploy metadata (commit, target, version, timestamp)

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/NevermoreCLIManifestUtils">View docs →</a></div>

## Installation

```
npm install @quenty/nevermoreclimanifest --save
```

## Usage

When a place is deployed with `nevermore deploy`, the CLI finds this package's
`NevermoreCLIManifestUtils` ModuleScript in the built place and writes the
deployment metadata onto it as attributes. Because the data rides on the
package's own instance it replicates to clients automatically, so any consumer
can read it from either the client or the server:

```lua
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")

local metadata = NevermoreCLIManifestUtils.getGameMetadata()
if metadata.deployed then
	print(string.format("%s @ %s (%s)", metadata.target, metadata.commit, metadata.timestamp))
else
	print("Undeployed build (Studio)")
end
```

`getGameMetadata()` returns a `GameMetadata` table:

| Field | Type | Description |
| --- | --- | --- |
| `deployed` | `boolean` | `true` only when injected by a `nevermore deploy` (false in Studio) |
| `commit` | `string?` | Short git commit SHA |
| `version` | `string?` | Full git commit SHA |
| `branch` | `string?` | Git branch the build was made from |
| `target` | `string?` | Deploy target name (e.g. `"test"`, `"integration"`) |
| `timestamp` | `string?` | ISO 8601 UTC time of the deploy |
| `published` | `boolean?` | `true` if published live (`--publish`), `false` if only Saved |
| `placeId` | `number?` | Roblox place ID deployed to |
| `universeId` | `number?` | Roblox universe ID deployed to |

Use `NevermoreCLIManifestUtils.observeGameMetadata()` for an `Observable` that
fires the current snapshot and again whenever a field changes (for example when
the metadata first replicates to a client), or `isDeployed()` for a quick
boolean check.

If a place does not depend on this package, the CLI finds no injection point and
the deploy proceeds unchanged.
