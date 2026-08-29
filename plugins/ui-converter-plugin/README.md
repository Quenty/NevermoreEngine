## UI-Converter-Plugin
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

Converts UI between Roblox instances and Blend.

<div align="center"><a href="https://create.roblox.com/store/asset/138098421396202/Quentys-BlendFusion-UI-Converter-Beta">Install on Roblox Creator Store→</a></div>

## Headless API

The plugin also converts without the widget being open, so external tooling (command bar scripts, MCP agents) can drive it. Create a `Folder` whose name starts with `UIConverterRequest`, add `ObjectValue` children pointing at the instances to convert (or none to convert the current selection), optionally set a `Library` attribute (`Blend`, `BlendUnpacked`, `Fusion`, `FusionUnpacked`), then parent the folder to `ServerStorage`. Build the folder fully before parenting it.

The plugin sets the folder's `Status` attribute to `working`, then `done` with the generated code in a `ModuleScript` named `Output` inside the folder, or `error` with the message in an `Error` attribute. The requester owns cleanup: destroy the folder when finished.

### Using it from an AI agent

If your agent can run Luau in Studio (e.g. via the Roblox Studio MCP), paste the following into its prompt, rules file, or a custom skill and it can convert UI without you touching the plugin:

```
The UI Converter plugin exposes a headless API for converting GUI instances to
Blend/Fusion source. To convert:

1. In one Luau execution, build a Folder with a unique name starting with
   "UIConverterRequest" (e.g. "UIConverterRequest_abc"). Add one ObjectValue
   child per root instance to convert (descendants are included). Optionally
   set a "Library" attribute: "Blend" (default), "BlendUnpacked", "Fusion",
   or "FusionUnpacked". Only after the folder is fully built, parent it to
   ServerStorage. With no ObjectValue children, the current Studio selection
   is converted instead.
2. Poll the folder's "Status" attribute (task.wait loop is fine): it goes
   nil -> "working" -> "done" or "error". The first conversion per session
   downloads the Roblox API dump, so allow ~15 seconds. If Status never
   leaves nil, the plugin is not installed or not loaded.
3. On "done", read the generated code from the ModuleScript named "Output"
   inside the folder. On "error", the message is in the "Error" attribute.
4. Always destroy the request folder afterward (this also removes Output),
   even on error, so the place is left untouched.
```

If you use Studio's built-in Assistant, you can also ask it to create a custom skill from this block (via its skill-creation flow) so the workflow triggers automatically whenever you ask for a Blend conversion.