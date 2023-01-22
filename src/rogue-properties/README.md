## RogueProperties
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

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/RogueProperty">View docs →</a></div>

Roguelike properties which can be modified by external provides -- and that modification can be attributed to a source.

## Installation
```
npm install @quenty/rogue-properties --save
```

## Design goals
We need a property system for a rogue-like or MMORPG style game that offers the following attributes.

1. Modifiable - Can modify a base property in a variety of ways (additive, multiplicative, et cetera)
2. Attributable - Can attribute the source of final computation, especially for UI.
3. Extensible - Can combine properties
4. Grounded in Roblox datamodel - Source of truth exists in Roblox so other people can modify it
5. Performant - Needs to run fast
6. Agnostic to server/client - Needs to be able to centralize in datatable.
7. Scriptable - Need to be able to apply weird scripts to data.
8. Levelable - Can scale with level!
9. Usable for other people - The computed value is just .Value under the object!

