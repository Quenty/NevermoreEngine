--[=[
	@class GameScalingHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")

local GameScalingHelper = setmetatable({}, BaseObject)
GameScalingHelper.ClassName = "GameScalingHelper"
GameScalingHelper.__index = GameScalingHelper

function GameScalingHelper.new(screenGui)
	local self = setmetatable(BaseObject.new(), GameScalingHelper)

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._isVertical = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isSmall = self._maid:Add(ValueObject.new(false, "boolean"))

	self._maid:GiveTask(self._absoluteSize:Observe():Pipe({
		Rx.map(function(size)
			if size.x <= 0 or size.y <= 0 then
				return false
			end

			return size.x/size.y <= 1
		end);
		Rx.distinct()
	}):Subscribe(function(isVertical)
		self._isVertical.Value = isVertical
	end))

	self._maid:GiveTask(self._absoluteSize:Observe():Pipe({
		Rx.map(function(size)
			if size.x > 0 and size.y > 0 and math.min(size.x, size.y) < 500 then
				return true
			else
				return false
			end
		end);
	}):Subscribe(function(isSmall)
		self._isSmall.Value = isSmall
	end))

	if screenGui then
		self:SetScreenGui(screenGui)
	end

	return self
end

function GameScalingHelper:ObserveIsSmall()
	return self._isSmall:Observe()
end

function GameScalingHelper:ObserveIsVertical()
	return self._isVertical:Observe()
end

function GameScalingHelper:GetAbsoluteSizeSetter()
	return function(absoluteSize)
		self:SetAbsoluteSize(absoluteSize)
	end
end

function GameScalingHelper:SetAbsoluteSize(absoluteSize)
	self._absoluteSize:Mount(absoluteSize)
end

function GameScalingHelper:SetScreenGui(screenGui)
	self:SetAbsoluteSize(RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize"))
end

return GameScalingHelper