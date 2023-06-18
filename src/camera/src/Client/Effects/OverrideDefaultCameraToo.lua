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

local OverrideDefaultCameraToo = {}
OverrideDefaultCameraToo.ClassName = "OverrideDefaultCameraToo"

--[=[
	Initializes a new OverrideDefaultCameraToo

	@param baseCamera Camera
	@param defaultCamera DefaultCamera
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
			self.DefaultCamera:SetRobloxCFrame(result.CFrame)
		end

		return result
	elseif index == "BaseCamera" or index == "DefaultCamera" or index == "Predicate" then
		return rawget(self, index)
	else
		return OverrideDefaultCameraToo[index]
	end
end

return OverrideDefaultCameraToo