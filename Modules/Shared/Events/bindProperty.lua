--- Binds a property of a Roblox action to a callback
-- @function bindProperty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local fastSpawn = require("fastSpawn")

local function bindProperty(obj, valueName, callback)
	assert(typeof(obj) == "Instance")
	assert(type(valueName) == "string")
	assert(type(callback) == "function")

	local baseMaid = Maid.new()
	local previous = nil

	local function firePropertyChanged(value)
		previous = value
		local maid = Maid.new()
		baseMaid._valueMaid = maid

		callback(maid, value, previous)
	end

	baseMaid:GiveTask(obj:GetPropertyChangedSignal(valueName):Connect(function()
		local value = obj[valueName]
		if value ~= previous then
			firePropertyChanged(value)
		end
	end))

	-- Safety first!
	fastSpawn(function()
		firePropertyChanged(obj[valueName])
	end)

	return baseMaid
end

return bindProperty