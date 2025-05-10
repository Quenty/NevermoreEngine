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

	local function render(baseRay)
		local maid = Maid.new()

		local ray = Ray.new(baseRay.Origin, baseRay.Direction.unit * 10000)

		maid:Add(Draw.ray(ray))

		local raycastResult = Workspace:Raycast(ray.Origin, ray.Direction)
		if raycastResult then
			maid:Add(Draw.point(raycastResult.Position, Color3.new(0.25, 1, 0.25), nil, 0.1))
		end

		topMaid._current = maid
	end

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

			local camera = Workspace.CurrentCamera
			local position = inputObject.Position
			local baseRay = camera:ViewportPointToRay(position.x, position.y, 0)

			-- selene: allow(global_usage)
			shared._lastDrawRayInput = baseRay

			render(baseRay)
		end
	end))

	task.spawn(function()
		-- selene: allow(global_usage)
		if shared._lastDrawRayInput then
			render(shared._lastDrawRayInput)
		end
	end)

	return function()
		topMaid:DoCleaning()
	end
end
