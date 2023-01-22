--[=[
	@class HandleHighlightModel
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Blend = require("Blend")
local Rx = require("Rx")

local HandleHighlightModel = setmetatable({}, BaseObject)
HandleHighlightModel.ClassName = "HandleHighlightModel"
HandleHighlightModel.__index = HandleHighlightModel

function HandleHighlightModel.new()
	local self = setmetatable(BaseObject.new(), HandleHighlightModel)

	self.IsMouseOver = Instance.new("BoolValue")
	self.IsMouseOver.Value = false
	self._maid:GiveTask(self.IsMouseOver)

	self.IsMouseDown = Instance.new("BoolValue")
	self.IsMouseDown.Value = false
	self._maid:GiveTask(self.IsMouseDown)

	self.IsHighlighted = Instance.new("BoolValue")
	self.IsHighlighted.Value = false
	self._maid:GiveTask(self.IsHighlighted)

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
function HandleHighlightModel:SetHandle(handle: Instance)
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
function HandleHighlightModel:ObservePercentPressed()
	return Blend.AccelTween(Blend.toPropertyObservable(self.IsMouseDown)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), 200)
end

--[=[
	Observes how highlighted the button is
	@return Observable<number>
]=]
function HandleHighlightModel:ObservePercentHighlighted()
	return Blend.AccelTween(self:ObservePercentHighlightedTarget(), 200)
end

--[=[
	Observes target for how highlighted the button is
	@return Observable<number>
]=]
function HandleHighlightModel:ObservePercentHighlightedTarget()
	return Blend.toPropertyObservable(self.IsHighlighted)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		})
end

function HandleHighlightModel:_updateHighlighted()
	self.IsHighlighted.Value = self.IsMouseOver.Value or self.IsMouseDown.Value
end

return HandleHighlightModel