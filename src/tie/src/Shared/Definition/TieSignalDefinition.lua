--[=[
	@class TieSignalDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalImplementation = require("TieSignalImplementation")
local TieSignalInterface = require("TieSignalInterface")

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

function TieSignalDefinition:Implement(folder, initialValue)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TieSignalImplementation.new(self, folder, initialValue)
end

function TieSignalDefinition:GetInterface(folder: Folder)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TieSignalInterface.new(folder, nil, self)
end

function TieSignalDefinition:GetMemberName()
	return self._signalName
end

return TieSignalDefinition