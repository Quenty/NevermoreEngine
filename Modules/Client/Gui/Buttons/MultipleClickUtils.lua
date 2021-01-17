--- Utility library for detecting multiple clicks or taps. Not good UX, but good for opening up a debug
-- menus
-- @module MultipleClickUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Signal = require("Signal")

local MultipleClickUtils = {}

local TIME_TO_CLICK_AGAIN = 0.5 -- Based upon windows default
local VALID_TYPES = {
	[Enum.UserInputType.MouseButton1] = true;
	[Enum.UserInputType.Touch] = true;
}

function MultipleClickUtils.getDoubleClickSignal(maid, gui)
	return MultipleClickUtils.getDoubleClickSignal(maid, gui, 2)
end

function MultipleClickUtils.getMultipleClickSignal(maid, gui, requiredCount)
	assert(maid)
	assert(typeof(gui) == "Instance")

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