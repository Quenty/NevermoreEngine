## LinearSystemsSolver
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

Solves linear systems in this format:

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

## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit