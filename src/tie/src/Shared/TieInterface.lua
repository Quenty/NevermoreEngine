--!nonstrict
--[=[
	Tie interfaces can be retrieved from an implementation and allow access to a specific call into the interface

	@class TieInterface
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local TieMethodInterfaceUtils = require("TieMethodInterfaceUtils")
local TiePropertyInterface = require("TiePropertyInterface")
local TieRealms = require("TieRealms")
local TieSignalInterface = require("TieSignalInterface")

local TieInterface = {}
TieInterface.ClassName = "TieInterface"
TieInterface.__index = TieInterface

export type TieInterface<T> =
	typeof(setmetatable(
		{} :: {
			_definition: any,
			_implParent: Instance?,
			_adornee: Instance?,
			_interfaceTieRealm: string,
			_memberDefinitionMap: { [string]: any },
		},
		{} :: typeof({ __index = TieInterface })
	))
	& T

function TieInterface.new<T>(
	definition,
	implParent: Instance?,
	adornee: Instance?,
	interfaceTieRealm: TieRealms.TieRealm
): TieInterface<T>
	local self: TieInterface<T> = setmetatable({} :: any, TieInterface)

	assert(implParent or adornee, "ImplParent or adornee required")

	self._definition = assert(definition, "No definition")
	self._interfaceTieRealm = assert(interfaceTieRealm, "No interfaceTieRealm")
	self._implParent = implParent -- could be nil
	self._adornee = adornee -- could be nil
	self._memberDefinitionMap = self._definition:GetMemberMap()

	return self
end

--[=[
	Returns whether this version of the definition is implemented to standard or not.

	@return boolean
]=]
function TieInterface.IsImplemented<T>(self: TieInterface<T>): boolean
	local implParent = rawget(self :: any, "_implParent")
	local adornee = rawget(self :: any, "_adornee")
	local definition = rawget(self :: any, "_definition")
	local interfaceTieRealm = rawget(self :: any, "_interfaceTieRealm")

	if implParent then
		if adornee then
			if implParent.Parent ~= adornee then
				return false
			end

			if definition:GetValidContainerNameSet(interfaceTieRealm)[implParent.Name] then
				return false
			end
		end

		return definition:IsImplementation(implParent, interfaceTieRealm)
	end

	return definition:HasImplementation(adornee, interfaceTieRealm)
end

--[=[
	Gets the adornee the tie interface is on if it can be found.

	@return Instance?
]=]
function TieInterface.GetTieAdornee<T>(self: TieInterface<T>): Instance?
	local adornee = rawget(self :: any, "_adornee")
	if adornee then
		return adornee
	end

	local implParent = rawget(self :: any, "_implParent")
	if implParent then
		return implParent.Parent
	end

	return nil
end

--[=[
	Observes if the interface is implemented

	@return Observable<boolean>
]=]
function TieInterface.ObserveIsImplemented<T>(self: TieInterface<T>): Observable.Observable<boolean>
	local implParent = rawget(self :: any, "_implParent")
	local adornee = rawget(self :: any, "_adornee")
	local definition = rawget(self :: any, "_definition")
	local interfaceTieRealm = rawget(self :: any, "_interfaceTieRealm")

	if implParent then
		if adornee then
			return definition:ObserveIsImplementationOn(implParent, adornee, interfaceTieRealm)
		else
			return definition:ObserveIsImplementation(implParent, interfaceTieRealm)
		end
	end

	return definition:ObserveIsImplemented(adornee, interfaceTieRealm)
end

function TieInterface.__index<T>(self: TieInterface<T>, index)
	local interfaceTieRealm = rawget(self :: any, "_interfaceTieRealm")

	local member = (rawget(self :: any, "_memberDefinitionMap") :: any)[index]
	local definition = rawget(self :: any, "_definition")
	local adornee = rawget(self :: any, "_adornee")
	local implParent = rawget(self :: any, "_implParent")

	if member then
		if member:IsAllowedOnInterface(interfaceTieRealm) then
			if member.ClassName == "TieMethodDefinition" then
				return TieMethodInterfaceUtils.get(self, member, implParent, adornee, interfaceTieRealm)
			elseif member.ClassName == "TieSignalDefinition" then
				return TieSignalInterface.new(implParent, adornee, member, interfaceTieRealm)
			elseif member.ClassName == "TiePropertyDefinition" then
				return TiePropertyInterface.new(implParent, adornee, member, interfaceTieRealm)
			else
				error(string.format("Unknown member definition %q", tostring(member.ClassName)))
			end
		else
			error(
				string.format(
					"[TieInterface] - %s is not allowed in realm '%s'. Specify realm to %s.",
					member:GetFriendlyName(),
					interfaceTieRealm,
					member:GetMemberTieRealm()
				)
			)
		end
	elseif TieInterface[index] then
		return TieInterface[index]
	else
		error(string.format("[TieInterface] - Bad %q is not a member of %s", tostring(index), definition:GetName()))
	end
end

return TieInterface
