--!strict
--[=[
	@class SampleValues
]=]

local require = require(script.Parent.loader).load(script)

local InstanceQuery = require("InstanceQuery")

local ORIENTATION_PRECISION = 1e4
local DESCRIBE_PRECISION = 1e4

local SampleValues = {}

local propertyNamesByKey: { [string]: { string } } = {}

function SampleValues.getPropertyNames(className: string, skipDeprecated: boolean?): { string }
	local key = if skipDeprecated then `{className}/current` else className
	local cached = propertyNamesByKey[key]
	if cached then
		return cached
	end

	local names: { string } = {}
	local ok, properties = pcall(function()
		return (game :: any):GetService("ReflectionService"):GetPropertiesOfClass(className)
	end)
	if ok and type(properties) == "table" then
		for _, property in properties do
			if type(property) ~= "table" or type(property.Name) ~= "string" then
				continue
			end
			local display = property.Display
			if skipDeprecated and type(display) == "table" and display.DeprecationMessage ~= nil then
				continue
			end
			table.insert(names, property.Name)
		end
	end

	if skipDeprecated then
		local listed = {}
		for _, name in names do
			listed[name] = true
		end
		for index = #names, 1, -1 do
			local name = names[index]
			local capitalized = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
			if capitalized ~= name and listed[capitalized] then
				table.remove(names, index)
			end
		end
	end

	propertyNamesByKey[key] = names
	return names
end

function SampleValues.read(instance: Instance, name: string, onValue: (string, any) -> ())
	local value
	if string.sub(name, 1, 1) == "@" then
		value = instance:GetAttribute(string.sub(name, 2))
	else
		local ok, read = InstanceQuery.tryIndex(instance, name)
		if not ok then
			return
		end
		value = read
	end

	if value ~= nil then
		SampleValues.flatten(name, value, onValue)
	end
end

function SampleValues.readAll(instance: Instance, onValue: (string, any) -> ())
	for _, property in SampleValues.getPropertyNames(instance.ClassName) do
		SampleValues.read(instance, property, onValue)
	end
	for attribute, value in instance:GetAttributes() do
		SampleValues.flatten(`@{attribute}`, value, onValue)
	end
end

function SampleValues.describe(instance: Instance, name: string): string?
	local parts: { string } = {}
	SampleValues.read(instance, name, function(_component: string, value: any)
		table.insert(parts, tostring(SampleValues._round(value)))
	end)
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

function SampleValues.present(value: any): (string, any)
	local parts: { string } = {}
	local structured: any = nil
	SampleValues.flatten("", value, function(component: string, componentValue: any)
		local rounded = SampleValues._round(componentValue)
		table.insert(parts, tostring(rounded))
		if component == "" then
			structured = rounded
			return
		end

		structured = structured or {}
		local names = string.split(string.sub(component, 2), ".")
		local node = structured
		for index = 1, #names - 1 do
			node[names[index]] = node[names[index]] or {}
			node = node[names[index]]
		end
		node[names[#names]] = rounded
	end)
	if typeof(value) == "CFrame" then
		local position = table.concat(parts, ", ", 1, 3)
		local orientation = table.concat(parts, ", ", 4, 6)
		return `pos {position}  rot {orientation}`, structured
	end
	return table.concat(parts, ", "), structured
end

function SampleValues.flatten(name: string, value: any, onValue: (string, any) -> ())
	local valueType = typeof(value)
	if valueType == "number" or valueType == "boolean" or valueType == "string" then
		onValue(name, value)
	elseif valueType == "UDim2" then
		SampleValues.flatten(`{name}.X`, value.X, onValue)
		SampleValues.flatten(`{name}.Y`, value.Y, onValue)
	elseif valueType == "UDim" then
		onValue(`{name}.Scale`, value.Scale)
		onValue(`{name}.Offset`, value.Offset)
	elseif valueType == "Vector2" then
		onValue(`{name}.X`, value.X)
		onValue(`{name}.Y`, value.Y)
	elseif valueType == "Vector3" then
		onValue(`{name}.X`, value.X)
		onValue(`{name}.Y`, value.Y)
		onValue(`{name}.Z`, value.Z)
	elseif valueType == "CFrame" then
		SampleValues.flatten(`{name}.Position`, value.Position, onValue)
		local x, y, z = value:ToOrientation()
		onValue(`{name}.Orientation.X`, SampleValues._toDegrees(x))
		onValue(`{name}.Orientation.Y`, SampleValues._toDegrees(y))
		onValue(`{name}.Orientation.Z`, SampleValues._toDegrees(z))
	elseif valueType == "Color3" then
		onValue(`{name}.R`, SampleValues._round(value.R * 255))
		onValue(`{name}.G`, SampleValues._round(value.G * 255))
		onValue(`{name}.B`, SampleValues._round(value.B * 255))
	elseif valueType == "EnumItem" then
		onValue(name, value.Name)
	elseif valueType == "Instance" then
		onValue(name, value:GetFullName())
	else
		onValue(name, tostring(value))
	end
end

function SampleValues._round(value: any): any
	if type(value) ~= "number" then
		return value
	elseif SampleValues._isNanOrInfinite(value) then
		return tostring(value)
	end
	return SampleValues._withoutNegativeZero(math.round(value * DESCRIBE_PRECISION) / DESCRIBE_PRECISION)
end

function SampleValues._toDegrees(radians: number): number
	return SampleValues._withoutNegativeZero(
		math.round(math.deg(radians) * ORIENTATION_PRECISION) / ORIENTATION_PRECISION
	)
end

function SampleValues._isNanOrInfinite(value: number): boolean
	return value ~= value or math.abs(value) == math.huge
end

function SampleValues._withoutNegativeZero(value: number): number
	return value + 0
end

return SampleValues
