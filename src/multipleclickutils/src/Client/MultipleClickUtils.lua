--!strict
--[=[
	Utility library for detecting multiple clicks or taps. Not good UX, but good for opening up a debug
	menus.

	@class MultipleClickUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Signal = require("Signal")

local MultipleClickUtils = {}

local TIME_TO_CLICK_AGAIN = 0.5 -- Based upon windows default
local VALID_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

--[=[
	Observes a double click on the Gui
	@param gui GuiObject
	@return Observable<InputObject>
]=]
function MultipleClickUtils.observeDoubleClick(gui: GuiObject): Observable.Observable<InputObject>
	return MultipleClickUtils.observeMultipleClicks(gui, 2)
end

--[=[
	Returns a signal that fires when the player clicks or taps on a Gui twice.

	@param maid Maid
	@param gui GuiObject
	@return Signal<InputObject>
]=]
function MultipleClickUtils.getDoubleClickSignal(maid: Maid.Maid, gui: GuiObject): Signal.Signal<InputObject>
	return MultipleClickUtils.getMultipleClickSignal(maid, gui, 2)
end

--[=[
	Observes multiple clicks click on the Gui

	@param gui GuiObject
	@param requiredCount number
	@return Observable<InputObject>
]=]
function MultipleClickUtils.observeMultipleClicks(
	gui: GuiObject,
	requiredCount: number
): Observable.Observable<InputObject>
	assert(typeof(gui) == "Instance", "Bad gui")
	assert(type(requiredCount) == "number", "Bad requiredCount")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(MultipleClickUtils.getMultipleClickSignal(maid, gui, requiredCount):Connect(function(...)
			sub:Fire(...)
		end))

		return maid
	end) :: any
end

--[=[
	For use in Blend. Observes multiple clicks.

	```lua
	Blend.New "TextButton" {
		[MultipleClickUtils.onMultipleClicks(3)] = function()
			print("Clicked")
		end;
	};
	```

	@param requiredCount number
	@return (gui: GuiObject) -> Observable<InputObject>
]=]
function MultipleClickUtils.onMultipleClicks(
	requiredCount: number
): (gui: GuiObject) -> Observable.Observable<InputObject>
	assert(type(requiredCount) == "number", "Bad requiredCount")

	return function(gui: GuiObject)
		return MultipleClickUtils.observeMultipleClicks(gui, requiredCount)
	end
end

--[=[
	Returns a signal that fires when the player clicks or taps on a Gui a certain amount
	of times.

	@param maid Maid
	@param gui GuiObject
	@param requiredCount number
	@return Signal<InputObject>
]=]
function MultipleClickUtils.getMultipleClickSignal(
	maid,
	gui: GuiObject,
	requiredCount: number
): Signal.Signal<InputObject>
	assert(Maid.isMaid(maid), "Bad maid")
	assert(typeof(gui) == "Instance", "Bad gui")
	assert(type(requiredCount) == "number", "Bad requiredCount")

	local signal: Signal.Signal<InputObject> = maid:Add(Signal.new() :: any)

	local lastInputTime: number = 0
	local lastInputObject: InputObject? = nil
	local inputCount: number = 0

	maid:GiveTask(gui.InputBegan:Connect(function(inputObject)
		if not VALID_TYPES[inputObject.UserInputType] then
			return
		end

		if
			lastInputObject
			and inputObject.UserInputType == lastInputObject.UserInputType
			and (os.clock() - lastInputTime) <= TIME_TO_CLICK_AGAIN
		then
			inputCount = inputCount + 1

			if inputCount >= requiredCount then
				inputCount = 0
				lastInputTime = 0
				lastInputObject = nil
				signal:Fire(lastInputObject)
			end
		else
			inputCount = 1
			lastInputTime = os.clock()
			lastInputObject = inputObject
		end
	end))

	return signal
end

return MultipleClickUtils
