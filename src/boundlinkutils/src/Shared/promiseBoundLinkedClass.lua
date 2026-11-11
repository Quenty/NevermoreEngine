--!strict
--[=[
	Promise that returns an objectValue's value that has a bound
	value to it.

	@class promiseBoundLinkedClass
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Maid = require("Maid")
local Promise = require("Promise")

return function<T>(binder: Binder.Binder<T>, objValue: ObjectValue): Promise.Promise<T>
	if objValue.Value then
		local class = binder:Get(objValue.Value)
		if class then
			return Promise.resolved(class)
		end
	end

	local maid = Maid.new()
	local promise: Promise.Promise<T> = Promise.new() :: any

	local function watchValue()
		local value = objValue.Value
		if not value then
			maid._valueWatch = nil
			return
		end

		maid._valueWatch = binder:ObserveInstance(value, function(class)
			if class then
				promise:Resolve(class)
			end
		end)

		local class = binder:Get(value)
		if class then
			promise:Resolve(class)
		end
	end

	maid:GiveTask(objValue.Changed:Connect(watchValue))
	watchValue()

	promise:Finally(function()
		maid:Destroy()
	end)

	return promise
end
