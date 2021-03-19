--- Utilities involving signals
-- @module SignalUtils
local Nevermore = require(game.ReplicatedStorage:WaitForChild("Nevermore"))
local Signal = Nevermore("Signal")

local SignalUtils = {}

function SignalUtils.onNext(event, _function)
	assert(typeof(event) == "RBXScriptSignal" or (type(event) == "table" and getmetatable(event) == Signal))
	assert(type(_function) == "function")

	local conn
	conn = event:Connect(function(...)
		conn:Disconnect()
		_function(...)
	end)

	return conn
end

return SignalUtils
