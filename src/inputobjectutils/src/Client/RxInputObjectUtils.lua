--!strict
--[=[
	@class RxInputObjectUtils
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local InputObjectUtils = require("InputObjectUtils")
local Maid = require("Maid")
local Observable = require("Observable")

local RxInputObjectUtils = {}

--[=[
	Observes the input object ended event. This will fire immediately if the input object is already ended.

	@param initialInputObject InputObject
	@return Observable<()>
]=]
function RxInputObjectUtils.observeInputObjectEnded(initialInputObject: InputObject): Observable.Observable<()>
	assert(initialInputObject, "Bad initialInputObject")

	return Observable.new(function(sub)
		if initialInputObject.UserInputState == Enum.UserInputState.End then
			sub:Fire()
			sub:Complete()
			return
		end

		local maid = Maid.new()

		-- Handle mouse inputs
		maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
			if InputObjectUtils.isSameInputObject(initialInputObject, inputObject) then
				sub:Fire()
				sub:Complete()
			end
		end))

		-- Handle touch events
		maid:GiveTask(initialInputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if initialInputObject.UserInputState == Enum.UserInputState.End then
				sub:Fire()
				sub:Complete()
			end
		end))

		return maid
	end)
end

return RxInputObjectUtils
