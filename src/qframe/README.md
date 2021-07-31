## QFrame
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

CFrame representation as a quaternion

## Installation
```
npm install @quenty/qframe --save
```

## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting
- Changed how pow and multiplication work such that `O*(O^-1*B*O)^t*O^-1 = B^t` with the help of Trey
- Added AxisAngles (Trey) to contributors
- Added test project

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit