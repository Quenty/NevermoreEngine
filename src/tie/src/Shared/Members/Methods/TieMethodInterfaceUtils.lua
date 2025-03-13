--[=[
	@class TieMethodInterfaceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TieUtils = require("TieUtils")
local TieRealmUtils = require("TieRealmUtils")
local _TieRealms = require("TieRealms")

local TieMethodInterfaceUtils = {}

function TieMethodInterfaceUtils.get(aliasSelf, tieMethodDefinition, implParent, adornee: Instance?, interfaceTieRealm: _TieRealms.TieRealm)
	assert(TieRealmUtils.isTieRealm(interfaceTieRealm), "Bad interfaceTieRealm")

	local tieDefinition = tieMethodDefinition:GetTieDefinition()

	return function(firstArg, ...)
		if firstArg ~= aliasSelf then
			error(string.format("Must call methods with self as first parameter (Hint use `%s:%s()` instead of `%s.%s()`)",
				tieDefinition:GetName(),
				tieMethodDefinition:GetMemberName(),
				tieDefinition:GetName(),
				tieMethodDefinition:GetMemberName()))
		end

		if implParent and adornee then
			if implParent.Parent ~= adornee then
				error("implParent is not a parent of the adornee")
			end
		elseif implParent then
			implParent = implParent
		elseif adornee then
			-- Search the adornee (rip this is SO slow)

			local validContainerNameSet = tieDefinition:GetValidContainerNameSet(interfaceTieRealm)
			for containerName, _ in validContainerNameSet do
				local found = adornee:FindFirstChild(containerName)
				if found then
					local bindableFunction = found:FindFirstChild(tieMethodDefinition:GetMemberName())
					if bindableFunction then
						return TieUtils.decode(bindableFunction:Invoke(TieUtils.encode(...)))
					end
				end
			end

			error(string.format("No implemented for %s on %q", tieMethodDefinition:GetFriendlyName(), implParent:GetFullName()))
		end

		local bindableFunction = implParent:FindFirstChild(tieMethodDefinition:GetMemberName())
		if not bindableFunction then
			error(string.format("No implemented for %s on %q", tieMethodDefinition:GetFriendlyName(), implParent:GetFullName()))
		end

		return TieUtils.decode(bindableFunction:Invoke(TieUtils.encode(...)))
	end
end

return TieMethodInterfaceUtils