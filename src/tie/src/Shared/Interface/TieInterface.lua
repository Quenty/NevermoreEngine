--[=[
	@class TieInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieSignalInterface = require("TieSignalInterface")
local TiePropertyInterface = require("TiePropertyInterface")
local TieMethodInterfaceUtils = require("TieMethodInterfaceUtils")

local TieInterface = {}
TieInterface.ClassName = "TieInterface"
TieInterface.__index = TieInterface

function TieInterface.new(definition, folder, adornee)
	local self = setmetatable({}, TieInterface)

	assert(folder or adornee, "Folder or adornee required")

	self._definition = assert(definition, "No definition")
	self._folder = folder -- could be nil
	self._adornee = adornee -- could be nil
	self._memberDefinitionMap = self._definition:GetMemberMap()

	return self
end

--[=[
	Returns whether this version of the definition is implemented to standard or not.

	@return boolean
]=]
function TieInterface:IsImplemented()
	local folder = rawget(self, "_folder")
	local adornee = rawget(self, "_adornee")
	local definition = rawget(self, "_definition")

	if folder then
		if adornee then
			if folder.Parent ~= adornee then
				return false
			end

			if folder.Name ~= self:GetContainerName() then
				return false
			end
		end

		return definition:IsImplementation(folder)
	end

	return definition:HasImplementation(adornee)
end

--[=[
	Gets the adornee the tie interface is on if it can be found.

	@return Instance | nil
]=]
function TieInterface:GetTieAdornee()
	local adornee = rawget(self, "_adornee")
	if adornee then
		return adornee
	end

	local folder = rawget(self, "_folder")
	if folder then
		return folder.Parent
	end

	return nil
end

--[=[
	@return Observable<boolean>
]=]
function TieInterface:ObserveIsImplemented()
	local folder = rawget(self, "_folder")
	local adornee = rawget(self, "_adornee")
	local definition = rawget(self, "_definition")

	if folder then
		if adornee then
			return definition:ObserveIsImplementationOn(folder, adornee)
		else
			return definition:ObserveIsImplementation(folder)
		end
	end

	return definition:ObserveIsImplemented(adornee)
end

function TieInterface:__index(index)
	local member = rawget(self, "_memberDefinitionMap")[index]
	local definition = rawget(self, "_definition")
	if member and member:IsAllowed() then
		if member.ClassName == "TieMethodDefinition" then
			local adornee = rawget(self, "_adornee")
			local folder = rawget(self, "_folder")

			return TieMethodInterfaceUtils.get(self, definition, member, folder, adornee)
		elseif member.ClassName == "TieSignalDefinition" then
			local adornee = rawget(self, "_adornee")
			local folder = rawget(self, "_folder")

			return TieSignalInterface.new(folder, adornee, member)
		elseif member.ClassName == "TiePropertyDefinition" then
			local adornee = rawget(self, "_adornee")
			local folder = rawget(self, "_folder")

			return TiePropertyInterface.new(folder, adornee, member)
		else
			error(string.format("Unknown member definition %q", tostring(member.ClassName)))
		end
	elseif TieInterface[index] then
		return TieInterface[index]
	else
		error(string.format("Bad %q is not a member of %s", tostring(index), definition:GetContainerName()))
	end
end

return TieInterface