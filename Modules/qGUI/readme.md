# ScreenCover

ScreenCover can be used to make pretty transitions between screen states. This is most useful when loading a splash screen and/or teleport screen, but can be used in many contexts.

Overall, you should prefer alternatives to pure-GUI based transitions, but in certain cases, it is almost certainly easier to use this implementation.

Warning: ScreenCover has an archaic API.

### MakeCover
`ScreenCover.MakeCover(Properties)`
Creates a `Frame` that covers the screen. Properties is a table that should be used to set the parent and any other properties you want. These properties are applied after the default properties are applied.

```
local ScreenGui = ...
local MyCover = ScreenCover.MakeCover({
	Parent = ScreenGui;
	Name = "LoadingScreenCover";
})

```

### MakeScreenCover
`ScreenCover.MakeScreenCover(BaseCover, AnimationStyle)`
Creates a screen. `BaseCover` is a GUI frame that will be used as a property farm and container. All created GUI elements will be inside of this for the transition.
`AnimationStyle` is a table with specifications on animation style.

```
local ScreenGui = ...
local MyCover = ScreenCover.MakeCover({
	Parent = ScreenGui;
	Name = "LoadingScreenCover";
})

ScreenCover.MakeCover(MyCover, {
	AnimationStyle = "DiagonalSquares";
	Type = "TransitionIn";
	AnimationTime = 1;
	SquareSize = 76; -- Only on square transitions, optional
})
```

#### AnimationStyle.Type
Can either be "TransitionIn" or "TransitionOut." TransitionIn makes the GUI animate in. TransitionOut means the end-state the GUI is gone. TransitionIn means the end-state in the GUI is visible.

#### AnimationStyle.AnimationTime
This is the time it takes for the transition to occur. 

#### AnimationStyle.AnimationStyle
The style in which things animate in and out.

##### Fade
A simple fading transition

##### SlideDown
Slides down from the top of the screen

##### SlideUp
Slides up from the bottom of the screen

##### DiagonalSquares
Diagonal squares are generated from the top left corner, to the bottom right corner fading in. Note this UI doesn't scale. 

An additional property `SquareSize` that defaults to `76` is a part of AnimationStyles that can be used to specify this. It is in offset.

##### StraightSquare
Like diagonal, but straight. See DiagonalSquares for detail

##### Circle
Creates a circle sliding in and out, a-la Animal Crossing style. 