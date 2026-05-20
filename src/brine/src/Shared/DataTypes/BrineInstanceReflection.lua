--!strict
--[=[
    @class BrineInstanceReflection
]=]

local require = require(script.Parent.loader).load(script)

local ReflectionService = game:GetService("ReflectionService")

local MemorizeUtils = require("MemorizeUtils")

local BrineInstanceReflection = {}

export type PropertyMetadataEntry = {
	Name: string,
	DefaultValue: any,
}

export type PropertyMetadata = {
	lookup: { [string]: PropertyMetadataEntry },
	orderedList: { PropertyMetadataEntry },
}

local IGNORE_PROPERTIES = {
	["GuiObject"] = {
		-- This does weird stuff to text labels, but isn't serialized
		["Transparency"] = true,
	},
}

function BrineInstanceReflection.canConstruct(className: string, securityCapabilities: SecurityCapabilities): boolean
	local classInfo = ReflectionService:GetClass(className, {
		ExcludeDisplay = true,
		Security = securityCapabilities,
	})

	if not (classInfo.Permits.New and securityCapabilities:Contains(classInfo.Permits.New)) then
		return false
	end

	return true
end

BrineInstanceReflection.canConstructMemoized = MemorizeUtils.memoize(BrineInstanceReflection.canConstruct)

function BrineInstanceReflection.getEncodedProperties(
	className: string,
	securityCapabilities: SecurityCapabilities
): PropertyMetadata?
	if not BrineInstanceReflection.canConstructMemoized(className, securityCapabilities) then
		return nil
	end

	local defaultInstance = Instance.new(className)
	local propertiesInfo = ReflectionService:GetPropertiesOfClass(className, {
		ExcludeInherited = false,
		ExcludeDisplay = true,
		Security = securityCapabilities,
	})

	local lookup = {}
	local orderedList = {}
	for _, propertyInfo in propertiesInfo do
		if propertyInfo.Name == "Parent" then
			continue
		end
		if propertyInfo.Permits.Read == nil or not securityCapabilities:Contains(propertyInfo.Permits.Read) then
			continue
		end
		if IGNORE_PROPERTIES[propertyInfo.Owner] and IGNORE_PROPERTIES[propertyInfo.Owner][propertyInfo.Name] then
			continue
		end
		if propertyInfo.Permits.Write == nil or not securityCapabilities:Contains(propertyInfo.Permits.Write) then
			continue
		end

		local entry = {
			Name = propertyInfo.Name,
			DefaultValue = (defaultInstance :: any)[propertyInfo.Name],
		}

		lookup[propertyInfo.Name] = entry
		table.insert(orderedList, entry)
	end

	return table.freeze({
		lookup = table.freeze(lookup),
		orderedList = table.freeze(orderedList),
	})
end

BrineInstanceReflection.getEncodedPropertiesMemoized =
	MemorizeUtils.memoize(BrineInstanceReflection.getEncodedProperties)

return BrineInstanceReflection
