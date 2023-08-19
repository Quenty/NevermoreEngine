--[=[
	@class RoguePropertyChangedSignalConnection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local RoguePropertyChangedSignalConnection = {}
RoguePropertyChangedSignalConnection.ClassName = "RoguePropertyChangedSignalConnection"
RoguePropertyChangedSignalConnection.__index = RoguePropertyChangedSignalConnection

function RoguePropertyChangedSignalConnection.new(connect)
	local self = setmetatable({}, RoguePropertyChangedSignalConnection)

	self._maid = Maid.new()

	self._connected = true
	connect(self._maid)

	return self
end

function RoguePropertyChangedSignalConnection:Disconnect()
	self:Destroy()
end

function RoguePropertyChangedSignalConnection:__index(index)
	if index == "IsConnected" then
		return self._connected
	elseif RoguePropertyChangedSignalConnection[index] then
		return RoguePropertyChangedSignalConnection[index]
	else
		error(("Bad index %q for RoguePropertyChangedSignalConnection"):format(tostring(index)))
	end
end

function RoguePropertyChangedSignalConnection:Destroy()
	self._connected = false
	self._maid:DoCleaning()
	-- Avoid setting the metatable so calling methods is always valid
end

return RoguePropertyChangedSignalConnection