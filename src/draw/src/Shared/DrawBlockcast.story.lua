--[[
	@class Draw.story
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Draw = require("Draw")
local Maid = require("Maid")

return function(_target)
	local topMaid = Maid.new()

	topMaid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then
			return
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			if topMaid._current then
				if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					return
				end
			end

			local maid = Maid.new()
			local camera = Workspace.CurrentCamera
			local position = inputObject.Position

			local baseRay = camera:ViewportPointToRay(position.x, position.y, 0)
			local ray = Ray.new(baseRay.Origin, baseRay.Direction.unit * 50)
			local cframe = CFrame.new(ray.Origin, ray.Origin + ray.Direction.unit)
				* CFrame.Angles(0, math.pi / 4, math.pi / 4)
			local size = Vector3.new(4, 4, 4)
			local direction = ray.Direction

			maid:Add(Draw.blockcast(cframe, size, direction))

			local raycastResult = Workspace:Blockcast(cframe, size, direction)
			if raycastResult then
				maid:Add(Draw.point(raycastResult.Position, Color3.new(0.25, 1, 0.25), nil, 0.1))
			end

			topMaid._current = maid
		end
	end))

	return function()
		topMaid:DoCleaning()
	end
end
