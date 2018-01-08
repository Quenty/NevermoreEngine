local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ScrollingFrame = require("ScrollingFrame")
local Scrollbar = require("Scrollbar")

local scrollingFrame = ScrollingFrame.new(script.Parent)
scrollingFrame:AddScrollbar(Scrollbar.fromContainer(script.Parent.ScrollbarContainer))