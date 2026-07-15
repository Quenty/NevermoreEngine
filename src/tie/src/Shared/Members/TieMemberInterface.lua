--!strict
--[=[
	@class TieMemberInterface
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TieRealmUtils = require("TieRealmUtils")
local TieRealms = require("TieRealms")

local TieMemberInterface = {}
TieMemberInterface.ClassName = "TieMemberInterface"
TieMemberInterface.__index = TieMemberInterface

export type TieMemberInterface = typeof(setmetatable(
	{} :: {
		_implParent: Instance?,
		_adornee: Instance?,
		_memberDefinition: any,
		_interfaceTieRealm: TieRealms.TieRealm,
		_tieDefinition: any,
	},
	{} :: typeof({ __index = TieMemberInterface })
))

function TieMemberInterface.new(
	implParent: Instance?,
	adornee: Instance?,
	memberDefinition: any,
	interfaceTieRealm: TieRealms.TieRealm
): TieMemberInterface
	assert(TieRealmUtils.isTieRealm(interfaceTieRealm), "Bad interfaceTieRealm")

	local self: TieMemberInterface = setmetatable({} :: any, TieMemberInterface)

	assert(implParent or adornee, "Parent or adornee required")

	self._implParent = implParent
	self._adornee = adornee
	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._interfaceTieRealm = assert(interfaceTieRealm, "No interfaceTieRealm")

	self._tieDefinition = self._memberDefinition:GetTieDefinition()

	return self
end

function TieMemberInterface.GetInterfaceTieRealm(self: TieMemberInterface): TieRealms.TieRealm
	return self._interfaceTieRealm
end

function TieMemberInterface.GetImplParent(self: TieMemberInterface): Instance?
	local validContainerNameSet = self._tieDefinition:GetValidContainerNameSet(self._interfaceTieRealm)

	if self._implParent and self._adornee then
		if self._implParent.Parent == self._adornee and validContainerNameSet[self._implParent.Name] then
			return self._implParent
		else
			return nil
		end
	elseif self._implParent then
		if validContainerNameSet[self._implParent.Name] then
			return self._implParent
		else
			return nil
		end
	elseif self._adornee then
		-- TODO: What if there's nothing here?
		-- What if there's more than one?
		return self._tieDefinition:GetImplementationParents(self._adornee, self._interfaceTieRealm)[1]
	else
		error("Must have self._implParent or self._adornee")
	end
end

function TieMemberInterface.ObserveImplParentBrio(self: TieMemberInterface): Observable.Observable<Brio.Brio<Instance>>
	local validContainerNameSet = self._tieDefinition:GetValidContainerNameSet(self._interfaceTieRealm)

	if self._implParent and self._adornee then
		return (Rx.combineLatest({
			Parent = RxInstanceUtils.observeProperty(self._implParent, "Parent"),
			Name = RxInstanceUtils.observeProperty(self._implParent, "Name"),
		}) :: any):Pipe({
			Rx.map(function(state: any): any
				if validContainerNameSet[state.Name] and state.Parent == self._adornee then
					return self._implParent
				else
					return nil
				end
			end),
			Rx.distinct(),
			RxBrioUtils.toBrio(),
			RxBrioUtils.onlyLastBrioSurvives(),
		} :: { any })
	elseif self._implParent then
		return (RxInstanceUtils.observePropertyBrio(self._implParent, "Name", function(name)
			return validContainerNameSet[name]
		end) :: any):Pipe({
			RxBrioUtils.map(function(): any
				return self._implParent
			end),
		} :: { any })
	elseif self._adornee then
		return self._tieDefinition:ObserveValidContainerChildrenBrio(self._adornee, self._interfaceTieRealm)
	else
		error("No self._implParent or adornee")
	end
end

return TieMemberInterface
