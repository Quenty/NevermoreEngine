--[=[
	@class TieSignalInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalConnection = require("TieSignalConnection")

local TieSignalInterface = {}
TieSignalInterface.ClassName = "TieSignalInterface"
TieSignalInterface.__index = TieSignalInterface

function TieSignalInterface.new(adornee, memberDefinition)
	local self = setmetatable({}, TieSignalInterface)

	self._adornee = assert(adornee, "No adornee")
	self._memberDefinition = assert(memberDefinition, "No memberDefinition")

	return self
end

function TieSignalInterface:Connect(callback)
	assert(type(callback) == "function", "Bad callback")

	return TieSignalConnection.new(self._memberDefinition, self._adornee, callback)
end

return TieSignalInterface