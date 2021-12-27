## LinearSystemsSolver
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

Solves linear systems in this format:

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/LinearSystemsSolverUtils">View docs →</a></div>

## Installation
```
npm install @quenty/linearsystemssolver --save
```

```
[a  b | y]
[c  d | z]

mutSystem = {
	{a, b},
	{c, d},
}

mutOutput = {y, z}

returns solution {x0, x1}
```

## Notes
system and output get destroyed in the process
