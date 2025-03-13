--[=[
	@class AdorneePartBoundingBox
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local RxInstanceUtils = require("RxInstanceUtils")
local _Observable = require("Observable")

local AdorneePartBoundingBox = setmetatable({}, BaseObject)
AdorneePartBoundingBox.ClassName = "AdorneePartBoundingBox"
AdorneePartBoundingBox.__index = AdorneePartBoundingBox

function AdorneePartBoundingBox.new(part: BasePart)
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local self = setmetatable(BaseObject.new(part), AdorneePartBoundingBox)

	self._bbCFrame = self._maid:Add(ValueObject.new(nil))
	self._bbSize = self._maid:Add(ValueObject.new(Vector3.zero, "Vector3"))

	self._maid:GiveTask(RxInstanceUtils.observePropertyBrio(self._obj, "Anchored", function(anchored)
		return not anchored
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		self:_setupUnanchoredLoop(maid)
	end))

	self._bbSize.Value = self._obj.Size
	self._bbCFrame.Value = self._obj.CFrame

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Size"):Connect(function()
		self._bbSize.Value = self._obj.Size
	end))
	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("CFrame"):Connect(function()
		self._bbCFrame.Value = self._obj.CFrame
	end))

	return self
end

function AdorneePartBoundingBox:_setupUnanchoredLoop(maid)
	-- Paranoid
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		debug.profilebegin("adorneeboundingbox")
		self._bbCFrame.Value = self._obj.CFrame
		debug.profileend()
	end))
end

function AdorneePartBoundingBox:ObserveCFrame(): _Observable.Observable<CFrame>
	return self._bbCFrame:Observe()
end

function AdorneePartBoundingBox:ObserveSize(): _Observable.Observable<Vector3>
	return self._bbSize:Observe()
end

return AdorneePartBoundingBox