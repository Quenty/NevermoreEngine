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

	maid:GiveTask(objValue.Changed:Connect(function()
		local value = objValue.Value
		if value then
			local class = binder:Get(value)
			if class then
				promise:Resolve(class)
			end
		end
	end))

	maid:GiveTask(binder:GetClassAddedSignal():Connect(function(class, instance)
		if instance == objValue.Value then
			promise:Resolve(class)
		end
	end))

	promise:Finally(function()
		maid:Destroy()
	end)

	return promise
end
