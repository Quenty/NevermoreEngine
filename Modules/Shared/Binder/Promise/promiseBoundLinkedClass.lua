---
-- @function promiseBoundLinkedClass

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")
local Maid = require("Maid")

return function(binder, objValue)
	if objValue.Value then
		local class = binder:Get(objValue.Value)
		if class then
			return Promise.resolved(class)
		end
	end

	local maid = Maid.new()
	local promise = Promise.new()

	maid:GiveTask(objValue.Changed:Connect(function()
		local class = binder:Get(objValue.Value)
		if class then
			promise:Resolve(class)
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