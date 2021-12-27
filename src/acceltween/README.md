## AccelTween
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

Provides a means to, with both a continuous position and velocity,
accelerate from its current position to a target position in minimum time
given a maximum acceleration.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/AccelTween">View docs →</a></div>

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
