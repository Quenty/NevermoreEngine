--- Binds a property of a Roblox action to a callback
-- @function observeProperty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local deferred = require("deferred")
local Maid = require("Maid")
local Symbol = require("Symbol")

local EMPTY_SYMBOL = Symbol.named("emptySymbol")

local function observeProperty(obj, propertyName, callback)
	assert(typeof(obj) == "Instance")
	assert(type(propertyName) == "string")
	assert(type(callback) == "function")

	local baseMaid = Maid.new()
	local previous = EMPTY_SYMBOL

	local function firePropertyChanged(value)
		previous = value

		local maid = Maid.new()
		baseMaid._current = maid

		callback(maid, value)
	end

	baseMaid:GiveTask(obj:GetPropertyChangedSignal(propertyName):Connect(function()
		local value = obj[propertyName]
		if value ~= previous then
			firePropertyChanged(value)
		end
	end))

	-- Safety first!
	deferred(function()
		firePropertyChanged(obj[propertyName])
	end)

	return baseMaid
end

return observeProperty