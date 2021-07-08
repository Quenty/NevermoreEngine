## AccelTween

Provides a means to, with both a continuous position and velocity,
accelerate from its current position to a target position in minimum time
given a maximum acceleration.

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
