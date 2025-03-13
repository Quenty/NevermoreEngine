--[[
	Testing for convex hull logic

	@class ConvexHull3DUtils.story
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Draw = require("Draw")
local Maid = require("Maid")
local ConvexHull3DUtils = require("ConvexHull3DUtils")

local CORNERS = {
	Vector3.new( 0.5,  0.5, -0.5);
	Vector3.new( 0.5,  0.5,  0.5);
	Vector3.new( 0.5, -0.5, -0.5);
	Vector3.new( 0.5, -0.5,  0.5);
	Vector3.new(-0.5,  0.5, -0.5);
	Vector3.new(-0.5,  0.5,  0.5);
	Vector3.new(-0.5, -0.5, -0.5);
	Vector3.new(-0.5, -0.5,  0.5);
}

local function drawBlockCast(cframe, size, direction)
	local folder = Instance.new("Folder")
	folder.Name = "Blockcast"
	folder.Archivable = false

	local beginCFrame = cframe
	local finishCFrame = (cframe + direction)

	local box = Draw.box(cframe, size - Vector3.new(1, 1, 1)*0.1)
	box:FindFirstChildWhichIsA("BoxHandleAdornment"):Destroy()
	box.Parent = folder

	local box2 = Draw.box(cframe + direction, size - Vector3.new(1, 1, 1)*0.1)
	box2:FindFirstChildWhichIsA("BoxHandleAdornment"):Destroy()
	box2.Parent = folder

	local points = {}
	for _, corner in CORNERS do
		local beginPoint = beginCFrame:PointToWorldSpace(corner * size)
		local finishPoint = finishCFrame:PointToWorldSpace(corner * size)

		table.insert(points, beginPoint)
		table.insert(points, finishPoint)
	end

	local hullPoints = ConvexHull3DUtils.convexHull(points)

	ConvexHull3DUtils.drawVertices(hullPoints).Parent = folder
	folder.Parent = Draw.getDefaultParent()

	return folder
end

local function render(baseRay)
	local maid = Maid.new()

	local ray = Ray.new(baseRay.Origin, baseRay.Direction.unit * 8)
	local cframe = CFrame.new(ray.Origin, ray.Origin + ray.Direction.unit)
		* CFrame.Angles(0, math.pi/4, math.pi/4)

	local size = Vector3.new(4, 4, 4)
	local direction = ray.Direction

	-- Espeically hard cause it's colinear
	maid:Add(drawBlockCast(cframe, size, direction))

	return maid
end

return function(_target)
	local topMaid = Maid.new()

	topMaid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then
			return
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton3 then
			if topMaid._current then
				if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					return
				end
			end

			local camera = Workspace.CurrentCamera
			local position = inputObject.Position
			local baseRay = camera:ViewportPointToRay(position.x, position.y, 0)

			-- selene: allow(global_usage)
			shared._lastConvexHullInputRay = baseRay

			topMaid._current = render(baseRay)
		end
	end))

	-- selene: allow(global_usage)
	if shared._lastConvexHullInputRay then
		topMaid._current = render(shared._lastConvexHullInputRay)
	end

	return function()
		topMaid:DoCleaning()
	end
end