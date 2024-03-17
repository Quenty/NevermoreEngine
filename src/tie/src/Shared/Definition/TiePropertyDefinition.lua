--[=[
	@class TiePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TiePropertyImplementation = require("TiePropertyImplementation")
local TiePropertyInterface = require("TiePropertyInterface")
local TieRealmUtils = require("TieRealmUtils")

local TiePropertyDefinition = {}
TiePropertyDefinition.ClassName = "TiePropertyDefinition"
TiePropertyDefinition.__index = TiePropertyDefinition

function TiePropertyDefinition.new(tieDefinition, propertyName: string, defaultValue: any, realm)
	local self = setmetatable({}, TiePropertyDefinition)

	self._tieDefinition = assert(tieDefinition, "No tieDefinition")
	self._propertyName = assert(propertyName, "No propertyName")
	self._defaultValue = defaultValue
	self._tieRealm = assert(realm, "No realm")
	self._isRequired = TieRealmUtils.isRequired(self._tieRealm)
	self._isAllowed = TieRealmUtils.isAllowed(self._tieRealm)

	return self
end

function TiePropertyDefinition:GetTieDefinition()
	return self._tieDefinition
end

function TiePropertyDefinition:GetDefaultValue()
	return self._defaultValue
end

function TiePropertyDefinition:IsRequired(): boolean
	return self._isRequired
end

function TiePropertyDefinition:IsAllowed(): boolean
	return self._isAllowed
end

function TiePropertyDefinition:GetTieRealm()
	return self._tieRealm
end

function TiePropertyDefinition:Implement(folder: Folder, initialValue)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TiePropertyImplementation.new(self, folder, initialValue)
end

function TiePropertyDefinition:GetInterface(folder: Folder)
	assert(typeof(folder) == "Instance", "Bad folder")

	return TiePropertyInterface.new(folder, nil, self)
end

function TiePropertyDefinition:GetMemberName(): string
	return self._propertyName
end

return TiePropertyDefinition