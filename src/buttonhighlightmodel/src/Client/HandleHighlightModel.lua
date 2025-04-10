--!strict
--[=[
	@class HandleHighlightModel
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Blend = require("Blend")
local Rx = require("Rx")
local ValueObject = require("ValueObject")
local _Observable = require("Observable")

local HandleHighlightModel = setmetatable({}, BaseObject)
HandleHighlightModel.ClassName = "HandleHighlightModel"
HandleHighlightModel.__index = HandleHighlightModel

export type HandleHighlightModel = typeof(setmetatable(
	{} :: {
		IsMouseOver: ValueObject.ValueObject<boolean>,
		IsMouseDown: ValueObject.ValueObject<boolean>,
		IsHighlighted: ValueObject.ValueObject<boolean>,
	},
	{} :: typeof({ __index = HandleHighlightModel })
)) & BaseObject.BaseObject

function HandleHighlightModel.new(): HandleHighlightModel
	local self: HandleHighlightModel = setmetatable(BaseObject.new() :: any, HandleHighlightModel)

	self.IsMouseOver = self._maid:Add(ValueObject.new(false, "boolean"))

	self.IsMouseDown = self._maid:Add(ValueObject.new(false, "boolean"))

	self.IsHighlighted = self._maid:Add(ValueObject.new(false, "boolean"))

	self._maid:GiveTask(self.IsMouseDown.Changed:Connect(function()
		self:_updateHighlighted()
	end))
	self._maid:GiveTask(self.IsMouseOver.Changed:Connect(function()
		self:_updateHighlighted()
	end))
	self:_updateHighlighted()

	return self
end

--[=[
	Sets the handle for the highlight model.
	@param handle
]=]
function HandleHighlightModel.SetHandle(self: HandleHighlightModel, handle: HandleAdornment)
	assert(typeof(handle) == "Instance" or handle == nil, "Bad handle")

	local maid = Maid.new()

	if handle then
		maid:GiveTask(handle.MouseButton1Down:Connect(function()
			self.IsMouseDown.Value = true
		end))
		maid:GiveTask(handle.MouseButton1Up:Connect(function()
			self.IsMouseDown.Value = false
		end))
		maid:GiveTask(handle.MouseEnter:Connect(function()
			self.IsMouseOver.Value = true
		end))
		maid:GiveTask(handle.MouseLeave:Connect(function()
			self.IsMouseOver.Value = false
		end))

		maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				self.IsMouseDown.Value = false
			end
		end))
	end

	self._maid._buttonMaid = maid
end

--[=[
	Observes how pressed down the button is
	@return Observable<number>
]=]
function HandleHighlightModel.ObservePercentPressed(self: HandleHighlightModel): _Observable.Observable<number>
	return Blend.AccelTween(
		Blend.toPropertyObservable(self.IsMouseDown):Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end),
		}),
		200
	)
end

--[=[
	Observes how highlighted the button is
	@return Observable<number>
]=]
function HandleHighlightModel.ObservePercentHighlighted(self: HandleHighlightModel): _Observable.Observable<number>
	return Blend.AccelTween(self:ObservePercentHighlightedTarget(), 200)
end

--[=[
	Observes target for how highlighted the button is
	@return Observable<number>
]=]
function HandleHighlightModel.ObservePercentHighlightedTarget(
	self: HandleHighlightModel
): _Observable.Observable<number>
	return Blend.toPropertyObservable(self.IsHighlighted):Pipe({
		Rx.map(function(value)
			return value and 1 or 0
		end),
	})
end

function HandleHighlightModel._updateHighlighted(self: HandleHighlightModel): ()
	self.IsHighlighted.Value = self.IsMouseOver.Value or self.IsMouseDown.Value
end

return HandleHighlightModel