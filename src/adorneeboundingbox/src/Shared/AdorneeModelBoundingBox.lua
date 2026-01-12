--!strict
--[=[
	@class AdorneeModelBoundingBox
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSet = require("ObservableSet")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")

local AdorneeModelBoundingBox = setmetatable({}, BaseObject)
AdorneeModelBoundingBox.ClassName = "AdorneeModelBoundingBox"
AdorneeModelBoundingBox.__index = AdorneeModelBoundingBox

export type AdorneeModelBoundingBox =
	typeof(setmetatable(
		{} :: {
			_obj: Model,
			_bbCFrame: ValueObject.ValueObject<CFrame?>,
			_bbSize: ValueObject.ValueObject<Vector3?>,
			_isDirty: ValueObject.ValueObject<boolean>,
			_unanchoredPartsSet: ObservableSet.ObservableSet<BasePart>,
		},
		{} :: typeof({ __index = AdorneeModelBoundingBox })
	))
	& BaseObject.BaseObject

function AdorneeModelBoundingBox.new(model: Model): AdorneeModelBoundingBox
	local self: AdorneeModelBoundingBox = setmetatable(BaseObject.new(model) :: any, AdorneeModelBoundingBox)

	self._bbCFrame = self._maid:Add(ValueObject.new(nil))
	self._bbSize = self._maid:Add(ValueObject.new(nil))
	self._isDirty = self._maid:Add(ValueObject.new(false, "boolean"))
	self._unanchoredPartsSet = self._maid:Add(ObservableSet.new())

	self._maid:GiveTask(RxInstanceUtils.observeDescendantsBrio(self._obj, function(part)
		return part:IsA("BasePart")
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, part = brio:ToMaidAndValue()

		self:_handlePart(maid, part :: BasePart)
	end))

	self._maid:GiveTask(self:_observeBasisChanged():Subscribe(function()
		self._isDirty.Value = true
	end))

	self._maid:GiveTask(self._isDirty
		:Observe()
		:Pipe({
			Rx.where(function(value)
				return value
			end) :: any,
			Rx.throttleDefer() :: any,
		})
		:Subscribe(function()
			debug.profilebegin("modelboundingbox")
			self._isDirty.Value = false

			local bbCFrame, bbSize = self._obj:GetBoundingBox()
			self._bbSize.Value = bbSize
			self._bbCFrame.Value = bbCFrame
			debug.profileend()
		end))

	self._maid:GiveTask(self._unanchoredPartsSet
		:ObserveCount()
		:Pipe({
			Rx.map(function(value)
				return value > 0
			end) :: any,
			Rx.distinct() :: any,
		})
		:Subscribe(function(hasUnanchoredParts)
			if hasUnanchoredParts then
				self._maid._current = self:_setupUnanchoredLoop()
			else
				self._maid._current = nil
			end
		end))

	return self
end

function AdorneeModelBoundingBox._setupUnanchoredLoop(self: AdorneeModelBoundingBox): Maid.Maid
	local maid = Maid.new()

	-- Paranoid
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		self._isDirty.Value = true
	end))

	return maid
end

function AdorneeModelBoundingBox._handlePart(self: AdorneeModelBoundingBox, topMaid, part: BasePart)
	topMaid:GiveTask(RxInstanceUtils.observePropertyBrio(part, "Anchored", function(isAnchored)
		return not isAnchored
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		maid:GiveTask(self._unanchoredPartsSet:Add(brio:GetValue()))
	end))

	topMaid:GiveTask(part:GetPropertyChangedSignal("Size"):Connect(function()
		self._isDirty.Value = true
	end))
	topMaid:GiveTask(part:GetPropertyChangedSignal("CFrame"):Connect(function()
		self._isDirty.Value = true
	end))
	self._isDirty.Value = true
end

function AdorneeModelBoundingBox._observeBasisChanged(self: AdorneeModelBoundingBox): Observable.Observable<()>
	return RxInstanceUtils.observeProperty(self._obj, "PrimaryPart"):Pipe({
		Rx.switchMap(function(primaryPart)
			if primaryPart then
				return RxInstanceUtils.observeProperty(primaryPart, "PivotOffset")
			else
				return RxInstanceUtils.observeProperty(self._obj, "WorldPivot")
			end
		end) :: any,
	}) :: any
end

function AdorneeModelBoundingBox.ObserveCFrame(self: AdorneeModelBoundingBox): Observable.Observable<CFrame?>
	return self._bbCFrame:Observe()
end

function AdorneeModelBoundingBox.ObserveSize(self: AdorneeModelBoundingBox): Observable.Observable<Vector3?>
	return self._bbSize:Observe()
end

return AdorneeModelBoundingBox
