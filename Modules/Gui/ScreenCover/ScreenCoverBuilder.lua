---
-- @classmod ScreenCoverBuilder

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ScreenCover = require("ScreenCover")

local ScreenCoverBuilder = {}
ScreenCoverBuilder.__index = ScreenCoverBuilder
ScreenCoverBuilder.ClassName = "ScreenCoverBuilder"

function ScreenCoverBuilder.new(PlayerGui)
	local self = setmetatable({}, ScreenCoverBuilder)

	self._playerGui = PlayerGui or error("No PlayerGui")

	return self
end

--- Creates new ScreenCover
function ScreenCoverBuilder:Create(options)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScreenCover"

	if options.DisplayOrder then
		screenGui.DisplayOrder = options.DisplayOrder
	end

	local frame = Instance.new("Frame")
	frame.Name = "ScreenCover"
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.Active = true
	frame.Size = UDim2.new(1, 0, 1, 36)
	frame.Position = UDim2.new(0, 0, 0, -36)

	for _, property in pairs({"BackgroundColor3"}) do
		if options[property] then
			frame[property] = options[property]
		end
	end

	frame.Parent = screenGui

	local cover = ScreenCover.new(frame)
	cover:SetScreenGui(screenGui)

	screenGui.Parent = self._playerGui

	return cover
end


return ScreenCoverBuilder