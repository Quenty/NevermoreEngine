## Spring

A physical model of a spring, useful in many applications. Properties only evaluate
upon index making this model good for lazy applications


## API

`Spring = Spring.new(number position)`
	Creates a new spring in 1D
`Spring = Spring.new(Vector3 position)`
	Creates a new spring in 3D

`Spring.Position`
	Returns the current position
`Spring.Velocity`
	Returns the current velocity
`Spring.Target`
	Returns the target
`Spring.Damper`
	Returns the damper
`Spring.Speed`
	Returns the speed

`Spring.Target = number/Vector3`
	Sets the target
`Spring.Position = number/Vector3`
	Sets the position
`Spring.Velocity = number/Vector3`
	Sets the velocity
`Spring.Damper = number [0, 1]`
	Sets the spring damper, defaults to 1
`Spring.Speed = number [0, infinity)`
	Sets the spring speed, defaults to 1

`Spring:TimeSkip(number DeltaTime)`
	Instantly skips the spring forwards by that amount of now
`Spring:Impulse(number/Vector3 velocity)`
	Impulses the spring, increasing velocity by the amount given

## Visualization
by Defaultio: https://www.desmos.com/calculator/hn2i9shxbz
