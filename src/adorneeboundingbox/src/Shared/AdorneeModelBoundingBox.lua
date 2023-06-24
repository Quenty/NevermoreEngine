--[=[
	@class AdorneeModelBoundingBox
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local ObservableSet = require("ObservableSet")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")

local AdorneeModelBoundingBox = setmetatable({}, BaseObject)
AdorneeModelBoundingBox.ClassName = "AdorneeModelBoundingBox"
AdorneeModelBoundingBox.__index = AdorneeModelBoundingBox

function AdorneeModelBoundingBox.new(model)
	local self = setmetatable(BaseObject.new(model), AdorneeModelBoundingBox)

	self._bbCFrame = ValueObject.new(nil)
	self._maid:GiveTask(self._bbCFrame)

	self._bbSize = ValueObject.new(nil)
	self._maid:GiveTask(self._bbSize)

	self._isDirty = ValueObject.new(false, "boolean")
	self._maid:GiveTask(self._isDirty)

	self._unanchoredPartsSet = ObservableSet.new(false)
	self._maid:GiveTask(self._unanchoredPartsSet)

	self._maid:GiveTask(RxInstanceUtils.observeDescendantsBrio(self._obj, function(part)
		return part:IsA("BasePart")
	end):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local part = brio:GetValue()

		self:_handlePart(maid, part)
	end))

	self._maid:GiveTask(self:_observeBasisChanged():Subscribe(function()
		self._isDirty.Value = true
	end))

	self._maid:GiveTask(self._isDirty:Observe():Pipe({
		Rx.where(function(value)
			return value
		end);
		Rx.throttleDefer();
	}):Subscribe(function()
		self._isDirty.Value = false

		local bbCFrame, bbSize = self._obj:GetBoundingBox()
		self._bbSize.Value = bbSize
		self._bbCFrame.Value = bbCFrame
	end))

	self._maid:GiveTask(self._unanchoredPartsSet:ObserveCount():Pipe({
		Rx.map(function(value)
			return value > 0
		end);
		Rx.distinct();
	}):Subscribe(function(hasUnanchoredParts)
		if hasUnanchoredParts then
			self._maid._current = self:_setupUnanchoredLoop()
		else
			self._maid._current = nil
		end
	end))

	return self
end

function AdorneeModelBoundingBox:_setupUnanchoredLoop()
	local maid = Maid.new()

	-- Paranoid
	maid:GiveTask(RunService.Heartbeat:Connect(function()
		self._isDirty.Value = true
	end))

	return maid
end

function AdorneeModelBoundingBox:_handlePart(topMaid, part)
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

function AdorneeModelBoundingBox:_observeBasisChanged()
	return RxInstanceUtils.observeProperty(self._obj, "PrimaryPart"):Pipe({
		Rx.switchMap(function(primaryPart)
			if primaryPart then
				return RxInstanceUtils.observeProperty(primaryPart, "PivotOffset")
			else
				return RxInstanceUtils.observeProperty(self._obj, "WorldPivot")
			end
		end)
	})
end

function AdorneeModelBoundingBox:ObserveCFrame()
	return self._bbCFrame:Observe()
end

function AdorneeModelBoundingBox:ObserveSize()
	return self._bbSize:Observe()
end

return AdorneeModelBoundingBox