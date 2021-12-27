--[=[
	Utility library for detecting multiple clicks or taps. Not good UX, but good for opening up a debug
	menus.

	@class MultipleClickUtils
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Maid = require("Maid")

local MultipleClickUtils = {}

local TIME_TO_CLICK_AGAIN = 0.5 -- Based upon windows default
local VALID_TYPES = {
	[Enum.UserInputType.MouseButton1] = true;
	[Enum.UserInputType.Touch] = true;
}

--[=[
	Returns a signal that fires when the player clicks or taps on a Gui twice.

	@param maid Maid
	@param gui GuiBase
	@return Signal<T>
]=]
function MultipleClickUtils.getDoubleClickSignal(maid, gui)
	return MultipleClickUtils.getDoubleClickSignal(maid, gui, 2)
end

--[=[
	Returns a signal that fires when the player clicks or taps on a Gui a certain amount
	of times.

	@param maid Maid
	@param gui GuiBase
	@param requiredCount number
	@return Signal<T>
]=]
function MultipleClickUtils.getMultipleClickSignal(maid, gui, requiredCount)
	assert(Maid.isMaid(maid), "Bad maid")
	assert(typeof(gui) == "Instance", "Bad gui")

	local signal = Signal.new()
	maid:GiveTask(signal)

	local lastInputTime = 0
	local lastInputObject = nil
	local inputCount = 0

	maid:GiveTask(gui.InputBegan:Connect(function(inputObject)
		if not VALID_TYPES[inputObject.UserInputType] then
			return
		end

		if lastInputObject
			and inputObject.UserInputType == lastInputObject.UserInputType
			and (tick() - lastInputTime) <= TIME_TO_CLICK_AGAIN then

			inputCount = inputCount + 1

			if inputCount >= requiredCount then
				inputCount = 0
				lastInputTime = 0
				lastInputObject = nil
				signal:Fire(lastInputObject)
			end
		else
			inputCount = 1
			lastInputTime = tick()
			lastInputObject = inputObject
		end
	end))

	return signal
end

return MultipleClickUtils