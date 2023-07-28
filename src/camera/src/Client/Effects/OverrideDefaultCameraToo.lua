--[=[
	Allows you to override the default camera with this cameras
	information. Useful for custom camera controls that the user
	controls.

	```lua
	local combiner = OverrideDefaultCameraToo.new(effect, self._cameraStackService:GetRawDefaultCamera())
	combiner.Predicate = function()
		return self._cameraStateTweener:IsFinishedShowing()
	end
	```

	@class OverrideDefaultCameraToo
]=]

local require = require(script.Parent.loader).load(script)

local SummedCamera = require("SummedCamera")
local Vector3Utils = require("Vector3Utils")

local OverrideDefaultCameraToo = {}
OverrideDefaultCameraToo.ClassName = "OverrideDefaultCameraToo"

--[=[
	Initializes a new OverrideDefaultCameraToo

	@param baseCamera Camera
	@param defaultCamera DefaultCamera
	@param predicate Filter on whether to override or not
]=]
function OverrideDefaultCameraToo.new(baseCamera, defaultCamera, predicate)
	local self = setmetatable({}, OverrideDefaultCameraToo)

	self.BaseCamera = assert(baseCamera, "No baseCamera")
	self.DefaultCamera = assert(defaultCamera, "No defaultCamera")
	self.Predicate = predicate

	return self
end

function OverrideDefaultCameraToo:__add(other)
	return SummedCamera.new(self, other)
end

function OverrideDefaultCameraToo:__newindex(index, value)
	if index == "BaseCamera" or index == "DefaultCamera" or index == "Predicate" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of OverrideDefaultCameraToo")
	end
end

function OverrideDefaultCameraToo:__index(index)
	if index == "CameraState" then
		local result = self.BaseCamera.CameraState

		local predicate = self.Predicate
		if not predicate or predicate(result) then
			local angle = math.abs(Vector3Utils.angleBetweenVectors(result.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1)), Vector3.new(0, 1, 0)))

			-- If the camera is straight up and down then Roblox breaks
			if angle >= math.rad(0.1) and angle <= math.rad(179.9) then
				self.DefaultCamera:SetRobloxCFrame(result.CFrame)
			end
		end

		return result
	elseif index == "BaseCamera" or index == "DefaultCamera" or index == "Predicate" then
		return rawget(self, index)
	else
		return OverrideDefaultCameraToo[index]
	end
end

return OverrideDefaultCameraToo