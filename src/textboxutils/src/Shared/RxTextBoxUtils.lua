--!strict
--[=[
	@class RxTextBoxUtils
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Maid = require("Maid")

local RxTextBoxUtils = {}

--[=[
	Observes whether or not a TextBox is focused

	@param textBox TextBox
	@return Observable<boolean>
]=]
function RxTextBoxUtils.observeIsFocused(textBox: TextBox): Observable.Observable<boolean>
	assert(typeof(textBox) == "Instance" and textBox:IsA("TextBox"), "Bad textBox")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(textBox.Focused:Connect(function()
			sub:Fire(true)
		end))

		maid:GiveTask(textBox.FocusLost:Connect(function()
			sub:Fire(false)
		end))

		sub:Fire(textBox:IsFocused())

		return maid
	end) :: any
end

return RxTextBoxUtils
