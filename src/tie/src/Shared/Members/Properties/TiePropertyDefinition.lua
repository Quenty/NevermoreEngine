--[=[
	@class TiePropertyDefinition
]=]

local require = require(script.Parent.loader).load(script)

local TieMemberDefinition = require("TieMemberDefinition")
local TiePropertyImplementation = require("TiePropertyImplementation")
local TiePropertyInterface = require("TiePropertyInterface")
local TieRealmUtils = require("TieRealmUtils")

local TiePropertyDefinition = setmetatable({}, TieMemberDefinition)
TiePropertyDefinition.ClassName = "TiePropertyDefinition"
TiePropertyDefinition.__index = TiePropertyDefinition

function TiePropertyDefinition.new(tieDefinition, propertyName: string, defaultValue: any, memberTieRealm)
	assert(TieRealmUtils.isTieRealm(memberTieRealm), "Bad memberTieRealm")

	local self =
		setmetatable(TieMemberDefinition.new(tieDefinition, propertyName, memberTieRealm), TiePropertyDefinition)

	self._defaultValue = defaultValue

	return self
end

function TiePropertyDefinition:GetDefaultValue()
	return self._defaultValue
end

function TiePropertyDefinition:IsRequiredForImplementation(currentRealm): boolean
	-- Override
	if getmetatable(TiePropertyDefinition).IsRequiredForImplementation(self, currentRealm) then
		if self:GetDefaultValue() ~= nil then
			return false
		end

		return true
	end

	return false
end

function TiePropertyDefinition:Implement(implParent: Instance, initialValue, _actualSelf, tieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TiePropertyImplementation.new(self, implParent, initialValue, tieRealm)
end

function TiePropertyDefinition:GetInterface(implParent: Instance, _actualSelf, tieRealm)
	assert(typeof(implParent) == "Instance", "Bad implParent")
	assert(TieRealmUtils.isTieRealm(tieRealm), "Bad tieRealm")

	return TiePropertyInterface.new(implParent, nil, self, tieRealm)
end

return TiePropertyDefinition
