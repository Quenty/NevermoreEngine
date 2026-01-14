--!strict
--[=[
	@class AdorneePartBoundingBox
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Observable = require("Observable")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")
local AdorneePartBoundingBox = setmetatable({}, BaseObject)
AdorneePartBoundingBox.ClassName = "AdorneePartBoundingBox"
AdorneePartBoundingBox.__index = AdorneePartBoundingBox

export type AdorneePartBoundingBox =
	typeof(setmetatable(
		{} :: {
			_obj: BasePart,
			_bbCFrame: ValueObject.ValueObject<CFrame?>,
			_bbSize: ValueObject.ValueObject<Vector3?>,
		},
		{} :: typeof({ __index = AdorneePartBoundingBox })
	))
	& BaseObject.BaseObject

function AdorneePartBoundingBox.new(part: BasePart): AdorneePartBoundingBox
	assert(typeof(part) == "Instance" and part:IsA("BasePart"), "Bad part")

	local self: AdorneePartBoundingBox = setmetatable(BaseObject.new(part) :: any, AdorneePartBoundingBox)

	self._bbCFrame = self._maid:Add(ValueObject.new(self._obj.CFrame, "CFrame") :: any)
	self._bbSize = self._maid:Add(ValueObject.new(self._obj.Size, "Vector3") :: any)

	self._maid:GiveTask(RxInstanceUtils.observePropertyBrio(self._obj, "Anchored", function(anchored)
		return not anchored
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		self:_setupUnanchoredLoop(maid)
	end))

	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("Size"):Connect(function()
		self._bbSize.Value = self._obj.Size
	end))
	self._maid:GiveTask(self._obj:GetPropertyChangedSignal("CFrame"):Connect(function()
		self._bbCFrame.Value = self._obj.CFrame
	end))

	return self
end

function AdorneePartBoundingBox._setupUnanchoredLoop(self: AdorneePartBoundingBox, maid: Maid.Maid): ()
	-- Paranoid
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		debug.profilebegin("adorneeboundingbox")
		self._bbCFrame.Value = self._obj.CFrame
		debug.profileend()
	end))
end

function AdorneePartBoundingBox.ObserveCFrame(self: AdorneePartBoundingBox): Observable.Observable<CFrame?>
	return self._bbCFrame:Observe()
end

function AdorneePartBoundingBox.ObserveSize(self: AdorneePartBoundingBox): Observable.Observable<Vector3?>
	return self._bbSize:Observe()
end

return AdorneePartBoundingBox
