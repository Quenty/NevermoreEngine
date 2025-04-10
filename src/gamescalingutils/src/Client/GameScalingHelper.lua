--!strict
--[=[
	@class GameScalingHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local ValueObject = require("ValueObject")
local _Maid = require("Maid")
local _Observable = require("Observable")

local GameScalingHelper = setmetatable({}, BaseObject)
GameScalingHelper.ClassName = "GameScalingHelper"
GameScalingHelper.__index = GameScalingHelper

export type GameScalingHelper = typeof(setmetatable(
	{} :: {
		_absoluteSize: ValueObject.ValueObject<Vector2>,
		_isVertical: ValueObject.ValueObject<boolean>,
		_isSmall: ValueObject.ValueObject<boolean>,
		_screenGui: ScreenGui?,
	},
	{} :: typeof({ __index = GameScalingHelper })
)) & BaseObject.BaseObject

function GameScalingHelper.new(screenGui: ScreenGui): GameScalingHelper
	local self = setmetatable(BaseObject.new() :: any, GameScalingHelper)

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._isVertical = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isSmall = self._maid:Add(ValueObject.new(false, "boolean"))

	self._maid:GiveTask(self._absoluteSize
		:Observe()
		:Pipe({
			Rx.map(function(size)
				if size.x <= 0 or size.y <= 0 then
					return false
				end

				return size.x / size.y <= 1
			end),
			Rx.distinct() :: any,
		})
		:Subscribe(function(isVertical)
			self._isVertical.Value = isVertical
		end))

	self._maid:GiveTask(self._absoluteSize
		:Observe()
		:Pipe({
			Rx.map(function(size)
				if size.x > 0 and size.y > 0 and math.min(size.x, size.y) < 500 then
					return true
				else
					return false
				end
			end),
		})
		:Subscribe(function(isSmall)
			self._isSmall.Value = isSmall
		end))

	if screenGui then
		self:SetScreenGui(screenGui)
	end

	return self
end

function GameScalingHelper.ObserveIsSmall(self: GameScalingHelper): _Observable.Observable<boolean>
	return self._isSmall:Observe()
end

function GameScalingHelper.ObserveIsVertical(self: GameScalingHelper): _Observable.Observable<boolean>
	return self._isVertical:Observe()
end

function GameScalingHelper.GetAbsoluteSizeSetter(self: GameScalingHelper): (absoluteSize: Vector2) -> ()
	return function(absoluteSize: Vector2)
		self:SetAbsoluteSize(absoluteSize)
	end
end

--[=[
	Sets the absolute size of the screen
]=]
function GameScalingHelper.SetAbsoluteSize(
	self: GameScalingHelper,
	absoluteSize: Vector2 | _Observable.Observable<Vector2>
): () -> ()
	return self._absoluteSize:Mount(absoluteSize)
end

--[=[
	Sets the screenGui to observe the absolute size from
	@param screenGui ScreenGui
]=]
function GameScalingHelper.SetScreenGui(self: GameScalingHelper, screenGui: ScreenGui): () -> ()
	return self:SetAbsoluteSize(RxInstanceUtils.observeProperty(screenGui, "AbsoluteSize"))
end

return GameScalingHelper