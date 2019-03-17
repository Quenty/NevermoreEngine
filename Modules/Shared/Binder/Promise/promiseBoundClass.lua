--- Utility function to promise a bound class on an object
-- @function promiseBoundClass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Maid = require("Maid")

return function(binder, inst)
	local class = binder:Get(inst)
	if class then
		return Promise.resolved(class)
	end

	local maid = Maid.new()
	local promise = Promise.new()
	maid:GiveTask(binder:GetClassAddedSignal():Connect(function(classAdded, instance)
		if instance == inst then
			promise:Resolve(classAdded)
		end
	end))

	promise:Finally(function()
		maid:Destroy()
	end)

	return promise
end