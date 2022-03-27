--[=[
	@class TieSignalDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalDefinition = {}
TieSignalDefinition.ClassName = "TieSignalDefinition"
TieSignalDefinition.__index = TieSignalDefinition

function TieSignalDefinition.new(tieDefinition, signalName)
	local self = setmetatable({}, TieSignalDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._signalName = assert(signalName, "No signalName")

	return self
end

function TieSignalDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TieSignalDefinition:GetMemberName()
	return self._signalName
end

return TieSignalDefinition