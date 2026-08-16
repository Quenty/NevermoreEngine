## Iris

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

Immediate-mode GUI vendored from [SirMallard/Iris](https://github.com/SirMallard/Iris) (v2.5.1), plus `Iris.ImPlotGraph` / `Iris.ImPlotPieChart` from [LinusKat/ImPlot](https://github.com/LinusKat/ImPlot). Those two are not upstream Iris — they are extra widgets. `PlotLines` / `PlotHistogram` remain the built-in sparkline widgets.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Iris">View docs →</a></div>

## Installation

```
npm install @quenty/iris --save
```

```lua
local Iris = require("Iris")
```

## Source

Vendored from [SirMallard/Iris](https://github.com/SirMallard/Iris) v2.5.1. MIT, copyright 2024 Michael_48.

`widgets/iris_ImPlot/` is extracted from [LinusKat/ImPlot](https://github.com/LinusKat/ImPlot). MIT, copyright 2026 LinusKat. That repo is a full Iris fork with plot widgets; only the unique plot code is kept here.

Files are prefixed `iris_` so they do not collide in Nevermore's global module registry. Relative requires are unchanged. Re-vendor from a tagged release next time and record the SHA here.
