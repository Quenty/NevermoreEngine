## Conditions
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

Adornee based conditional system that is sufficiently generic to script gameplay.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/AdorneeConditionUtils">View docs →</a></div>

## Installation
```
npm install @quenty/conditions --save
```

## Design challenges

The issue for conditions is they must be scriptable enough that anything can implement them, including external consumers, but flexibile enough that any gameplay can be constructed with them.

Additionally, we want to observe conditions for an adornee over specifically having them on a loop, so we want to definitely leverage Observables/Rx here.

Finally, there's a networking component here, where we want to define code once, but network it across many places. But we're also latency sensitive for conditions, that is, we should be able to deny actions as soon as they occur on the client.

## Design results

For this reason, we end up with basically just a way to bind functions to a folder. Thus, we're scriptable. To allow replication/avoid duplicate implementation at the server/client layer we'll add another layer here where we'll bind conditions to the client/server.

