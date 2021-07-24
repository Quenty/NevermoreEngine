## AccelTween
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

Provides a means to, with both a continuous position and velocity,
accelerate from its current position to a target position in minimum time
given a maximum acceleration.

## Installation
```
npm install @quenty/acceltween --save
```

## API

`AccelTween = AccelTween.new(number maxaccel = 1)`
	maxaccel is the maximum acceleration applied to reach its target.

`number AccelTween.p`
	Returns the current position.
`number AccelTween.v`
	Returns the current velocity.
`number AccelTween.a`
	Returns the maximum acceleration.
`number AccelTween.t`
	Returns the target position.
`number AccelTween.rtime`
	Returns the remaining time before the AccelTween attains the target.

`AccelTween.p = number`
	Sets the current position.
`AccelTween.v = number`
	Sets the current velocity.
`AccelTween.a = number`
	Sets the maximum acceleration.
`AccelTween.t = number`
	Sets the target position.
`AccelTween.pt = number`
	Sets the current and target position, and sets the velocity to 0.

## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit