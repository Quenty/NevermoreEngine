--[=[
	@class TiePropertyChangedSignalConnection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")

local TiePropertyChangedSignalConnection = {}
TiePropertyChangedSignalConnection.ClassName = "TiePropertyChangedSignalConnection"
TiePropertyChangedSignalConnection.__index = TiePropertyChangedSignalConnection

function TiePropertyChangedSignalConnection.new(connect)
	local self = setmetatable({}, TiePropertyChangedSignalConnection)

	self._maid = Maid.new()

	self._connected = true
	connect(self._maid)

	return self
end

function TiePropertyChangedSignalConnection:Disconnect()
	self:Destroy()
end

function TiePropertyChangedSignalConnection:__index(index)
	if index == "IsConnected" then
		return self._connected
	elseif TiePropertyChangedSignalConnection[index] then
		return TiePropertyChangedSignalConnection[index]
	else
		error(string.format("Bad index %q for TiePropertyChangedSignalConnection", tostring(index)))
	end
end

function TiePropertyChangedSignalConnection:Destroy()
	self._connected = false
	self._maid:DoCleaning()
	-- Avoid setting the metatable so calling methods is always valid
end

return TiePropertyChangedSignalConnection