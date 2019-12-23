### Camera State
CameraState is an immutable camera system used for camera interpolation. Designed to make camera effects easy, it trades some efficiency and speed for making a not confusing camera system.

Camera state stores internal state of Coordinate frames as quaternions. This means that the classic lerp equation. Operations have been overridden to make this easier to work with.

Ok. It's not entirely immutable. They are kind of lazy, that is, reading data doesn't affect the state of them. There are no
required update loops or anything for the most part.

### Camera effect API
Current Camera Effects have the following API available. Adding new effects means that these two should follow the same API specifications

#### Add `+` operator
Returns a new Summed camera and adds the two effects together. This is used for combining effects

#### `.CameraState`
Indexing the CameraEffect should return the current camera state. This means that state is easy to index.

In previous versions, the following will also work. However, this is no longer true.

* `.State`
* `.CameraState`
* `.Camera`

This will return a `CameraState`

!!! warning
	Note that eventually we plan to deprecate everything but .CameraState

#### DefaultCamera
This class tracks the current camera ROBLOX uses and lets it maintain how it operates using a `BindToRenderStep` trick.

* Should call `BindToRenderStep` during construction
* Only one should exist at once per client (not enforced in code, however)

#### SummedCamera
This class takes two arguments and returns the summation of the two

* Arguments can be either `CameraState` or a CameraEffect, assuming the effect has a `CameraState` member

#### FadingCamera
This classes allows the effects of a camera to be faded / varied based upon a spring

* Starts at 0 percent effect
