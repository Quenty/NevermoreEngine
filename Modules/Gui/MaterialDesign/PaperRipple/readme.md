## What is PaperRipple?
Paper ripple is used to emulate the ripple effect as seen in Google's Material Design. It adds responsive feedback to your GUIs. 

## Using the PaperRipple to automatically add ripples to your buttons

```lua
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local PaperRipple = require("PaperRipple")

local TextButton = script.Parent -- This is your button
local Ripple = PaperRipple.FromParent(TextButton)
```