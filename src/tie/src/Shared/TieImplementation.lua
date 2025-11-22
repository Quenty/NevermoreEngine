--[=[
	This class represents the implementation for a given definition. For the lifetime
	of the class, this implementation will be exposed to consumption by both someone
	using the tie interface, and anyone invoking its methods via the normal Roblox API.

	@class TieImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local String = require("String")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")

local TieImplementation = setmetatable({}, BaseObject)
TieImplementation.ClassName = "TieImplementation"
TieImplementation.__index = TieImplementation

--[=[
	Constructs a new implementation. Use [TieDefinition.Implement] instead of using this directly.

	@param tieDefinition TieDefinition
	@param adornee Instance
	@param implementer table
	@param implementationTieRealm TieRealm
]=]
function TieImplementation.new(
	tieDefinition,
	adornee: Instance,
	implementer,
	implementationTieRealm: TieRealms.TieRealm
)
	assert(TieRealmUtils.isTieRealm(implementationTieRealm), "Bad implementationTieRealm")

	local self = setmetatable(BaseObject.new(), TieImplementation)

	self._tieDefinition = assert(tieDefinition, "No definition")
	self._adornee = assert(adornee, "No adornee")
	self._actualSelf = implementer or {}
	self._implementationTieRealm = assert(implementationTieRealm, "Bad implementationTieRealm")

	self._implParent = self._maid:Add(Instance.new(tieDefinition:GetNewImplClass(implementationTieRealm)))
	self._implParent.Archivable = false

	self._memberImplementations = {}
	self._memberMap = self._tieDefinition:GetMemberMap()

	self:_buildMemberImplementations(implementer)

	self._implParent.Parent = self._adornee

	-- Since "actualSelf" can be quite large, we clean up our stuff aggressively for GC.
	self._maid:GiveTask(function()
		self._maid:DoCleaning()

		for key, _ in pairs(self) do
			rawset(self, key, nil)
		end
	end)

	return self
end

function TieImplementation:GetImplementationTieRealm()
	return self._implementationTieRealm
end

function TieImplementation:GetImplParent()
	return self._implParent
end

function TieImplementation:__index(index)
	if TieImplementation[index] then
		return TieImplementation[index]
	end

	if
		index == "_implParent"
		or index == "_adornee"
		or index == "_tieDefinition"
		or index == "_memberImplementations"
		or index == "_implementationTieRealm"
		or index == "_memberMap"
		or index == "_actualSelf"
	then
		return rawget(self, index)
	end

	local memberMap = rawget(self, "_memberMap")
	local memberDefinition = memberMap[index]
	local implementationTieRealm = rawget(self, "_implementationTieRealm")

	if memberDefinition then
		if memberDefinition:IsAllowedForImplementation(self._implementationTieRealm) then
			return memberDefinition:GetInterface(self._implParent, self, implementationTieRealm)
		else
			error(
				string.format(
					"[TieImplementation] - %q is not available on %s",
					memberDefinition:GetFriendlyName(),
					self._implementationTieRealm
				)
			)
		end
	else
		error(string.format("Bad index %q for TieImplementation", tostring(index)))
	end
end

function TieImplementation:__newindex(index, value)
	if
		index == "_implParent"
		or index == "_adornee"
		or index == "_tieDefinition"
		or index == "_memberImplementations"
		or index == "_implementationTieRealm"
		or index == "_memberMap"
		or index == "_actualSelf"
	then
		rawset(self, index, value)
	elseif self._memberImplementations[index] then
		self._memberImplementations[index]:SetImplementation(value, self._actualSelf)
	elseif TieImplementation[index] then
		error(string.format("Cannot set %q in TieImplementation", tostring(index)))
	else
		error(string.format("Bad index %q for TieImplementation", tostring(index)))
	end
end

function TieImplementation:_buildMemberImplementations(implementer)
	for _, memberDefinition in self._memberMap do
		local memberName = memberDefinition:GetMemberName()
		local found = nil

		if implementer then
			found = implementer[memberName]
		end

		if memberDefinition:IsRequiredForImplementation(self._implementationTieRealm) then
			if not found then
				error(self:_getErrorMessageRequiredMember(memberDefinition))
			end
		end

		if found then
			if not memberDefinition:IsAllowedForImplementation(self._implementationTieRealm) then
				error(self:_getErrorMessageForNotAllowedMember(memberDefinition))
			end
		end

		local memberImplementation = self._maid:Add(
			memberDefinition:Implement(self._implParent, found, self._actualSelf, self._implementationTieRealm)
		)
		self._memberImplementations[memberDefinition:GetMemberName()] = memberImplementation
	end

	self._implParent.Name = self._tieDefinition:GetNewContainerName(self._implementationTieRealm)
end

function TieImplementation:_getErrorMessageForNotAllowedMember(memberDefinition)
	local errorMessage = string.format(
		"[TieImplementation] - Member implements %s only member %s (we are a %s implementation)",
		memberDefinition:GetMemberTieRealm(),
		memberDefinition:GetFriendlyName(),
		self._implementationTieRealm
	)

	if self._implementationTieRealm == TieRealms.SHARED then
		if memberDefinition:GetMemberTieRealm() ~= TieRealms.SHARED then
			errorMessage = string.format(
				"%s\n\tHINT: This is declared as a %s implementation. %s is only allowed on %s.",
				errorMessage,
				self._implementationTieRealm,
				memberDefinition:GetFriendlyName(),
				memberDefinition:GetMemberTieRealm()
			)
		end
	end

	return errorMessage
end

function TieImplementation:_getErrorMessageRequiredMember(memberDefinition)
	local errorMessage = string.format(
		"[TieImplementation] - Missing %s member %s (we are a %s implementation)",
		memberDefinition:GetMemberTieRealm(),
		memberDefinition:GetFriendlyName(),
		self._implementationTieRealm
	)

	if self._implementationTieRealm == TieRealms.SHARED then
		if memberDefinition:GetMemberTieRealm() ~= TieRealms.SHARED then
			errorMessage = string.format(
				"%s\n\tHINT: This is declared as a %s implementation. Shared implements require both client and server components. You could also specify the implementation realm by writing %sInterface.%s:Implement(...)",
				errorMessage,
				self._implementationTieRealm,
				self._tieDefinition:GetName(),
				String.uppercaseFirstLetter(memberDefinition:GetMemberTieRealm())
			)
		end
	end

	return errorMessage
end

return TieImplementation
