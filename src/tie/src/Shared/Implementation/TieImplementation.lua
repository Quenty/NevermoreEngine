--[=[
	This class represents the implementation for a given definition. For the lifetime
	of the class, this implementation will be exposed to consumption by both someone
	using the tie interface, and anyone invoking its methods via the normal Roblox API.

	@class TieImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieRealms = require("TieRealms")

local TieImplementation = setmetatable({}, BaseObject)
TieImplementation.ClassName = "TieImplementation"
TieImplementation.__index = TieImplementation

function TieImplementation.new(tieDefinition, adornee, implementer)
	local self = setmetatable(BaseObject.new(), TieImplementation)

	self._definition = assert(tieDefinition, "No definition")
	self._adornee = assert(adornee, "No adornee")
	self._actualSelf = implementer or {}

	self._folder = self._maid:Add(Instance.new("Folder"))
	self._folder.Archivable = false

	self._memberImplementations = {}
	self._memberMap = self._definition:GetMemberMap()

	self:_buildMemberImplementations(implementer)

	self._folder.Parent = self._adornee

	return self
end

function TieImplementation:GetFolder()
	return self._folder
end

function TieImplementation:__index(index)
	if TieImplementation[index] then
		return TieImplementation[index]
	end

	if index == "_folder"
		or index == "_adornee"
		or index == "_definition"
		or index == "_memberImplementations"
		or index == "_memberMap"
		or index == "_actualSelf" then

		return rawget(self, index)
	end

	local memberMap = rawget(self, "_memberMap")
	local memberDefinition = memberMap[index]
	if memberDefinition then
		if memberDefinition:IsAllowed() then
			return memberDefinition:GetInterface(self._folder, self)
		else
			error(string.format("%q is not a valid member", tostring(index)))
		end
	else
		error(string.format("Bad index %q for TieImplementation", tostring(index)))
	end
end

function TieImplementation:__newindex(index, value)
	if index == "_folder"
		or index == "_adornee"
		or index == "_definition"
		or index == "_memberImplementations"
		or index == "_memberMap"
		or index == "_actualSelf" then

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
	local allClientImplemented = true

	for _, memberDefinition in pairs(self._memberMap) do
		if not memberDefinition:IsAllowed() then
			if memberDefinition:GetTieRealm() == TieRealms.CLIENT then
				allClientImplemented = false
			end
			continue
		end

		local initialValue
		if implementer then
			local memberName = memberDefinition:GetMemberName()
			initialValue = implementer[memberName]
			if not initialValue then
				if memberDefinition:IsRequired() then
					error(string.format("Missing member %q on %q", memberName, self._adornee:GetFullName()))
				else
					if memberDefinition:GetTieRealm() == TieRealms.CLIENT then
						allClientImplemented = false
					end
					continue
				end
			end
		else
			initialValue = nil
		end

		local memberImplementation = self._maid:Add(memberDefinition:Implement(self._folder, initialValue, self._actualSelf))
		self._memberImplementations[memberDefinition:GetMemberName()] = memberImplementation
	end

	-- Hack to make server objects look like server
	if allClientImplemented then
		self._folder.Name = self._definition:GetContainerName()
	else
		self._folder.Name = self._definition:GetContainerNameForServer()
	end
end

return TieImplementation