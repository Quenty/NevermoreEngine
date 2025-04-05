--[=[
	@class UIConverterUtils
]=]

local require = require(script.Parent.loader).load(script)

local PromiseUtils = require("PromiseUtils")
local Math = require("Math")
local String = require("String")

export type UIConverterLibrary = "Blend" | "Fusion" | "FusionUnpacked" | "BlendUnpacked"

local UIConverterUtils = {}

local function applyToTuple(func, ...)
	local result = {}
	for _, item in { ... } do
		table.insert(result, func(item))
	end
	return unpack(result)
end

local function roundNumber(value: number): string
	if value == math.huge then
		return "math.huge"
	elseif value == -math.huge then
		return "-math.huge"
	else
		local formatted = string.format("%0.6f", value)
		local stripped = string.gsub(formatted, "%.?0+$", "")

		return stripped
	end
end

local function roundToPi(value: number): string?
	local closeTo = Math.round(value / math.pi, 1e-6)
	if closeTo == 0 then
		return "0"
	elseif closeTo == -1 then
		return "-math.pi"
	elseif closeTo == 1 then
		return "math.pi"
	else
		local fractionBottom = Math.round(math.pi / value, 1e-6)
		if math.floor(fractionBottom) == fractionBottom then
			if fractionBottom < 0 then
				return string.format("-math.pi/%d", math.abs(fractionBottom))
			else
				return string.format("math.pi/%d", fractionBottom)
			end
		end

		local deg = Math.round(math.deg(value), 1e-6)
		if math.floor(deg) == deg then
			return string.format("math.deg(%d)", deg)
		end

		return nil
	end
end

function UIConverterUtils.toMultiLineEscape(text: string): string
	if text:find("\n") then
		for i = 0, 250 do
			local equals = string.rep("=", i)
			local sep = string.format("%%[%s%%[", equals)
			local endSep = string.format("%%]%s%%]", equals)

			if not text:find(sep) and not text:find(endSep) then
				return string.format("%s%s%s", string.format("[%s[", equals), text, string.format("]%s]", equals))
			end
		end

		return string.format("[[%s]]", text)
	end

	return text
end

function UIConverterUtils.toLuaComment(text: string): string
	if text:find("\n") then
		return "--" .. UIConverterUtils.toMultiLineEscape("\n" .. text .. "\n")
	else
		return "-- " .. text
	end
end

function UIConverterUtils.toLuaPropertyString(value: any, debugHint: string): string
	local valueType = typeof(value)
	if valueType == "string" then
		local multiline = UIConverterUtils.toMultiLineEscape(value)
		if multiline then
			return multiline
		else
			return string.format("%q", value)
		end
	elseif valueType == "number" then
		return roundNumber(value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "Color3" then
		return string.format("Color3.fromRGB(%d, %d, %d)", value.R * 255, value.G * 255, value.B * 255)
	elseif valueType == "Vector2" then
		return string.format("Vector2.new(%s, %s)", applyToTuple(roundNumber, value.x, value.y))
	elseif valueType == "Vector3" then
		return string.format("Vector3.new(%s, %s, %s)", applyToTuple(roundNumber, value.x, value.y, value.z))
	elseif valueType == "CFrame" then
		if value.Rotation == CFrame.new() then
			return string.format("CFrame.new(%s, %s, %s)", applyToTuple(roundNumber, value.x, value.y, value.z))
		elseif value.x == 0 and value.y == 0 and value.z == 0 then
			local x, y, z = value:toEulerAnglesXYZ()
			return string.format("CFrame.Angles(%s, %s, %s)", applyToTuple(roundNumber, x, y, z))
		else
			local x, y, z = value:toEulerAnglesXYZ()
			local roundX, roundY, roundZ = roundToPi(x), roundToPi(y), roundToPi(z)

			if roundX and roundY and roundZ then
				return string.format(
					"CFrame.new(%s, %s, %s) * CFrame.Angles(%s, %s, %s)",
					roundNumber(value.x),
					roundNumber(value.y),
					roundNumber(value.z),
					roundX,
					roundY,
					roundZ
				)
			else
				return string.format(
					"CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
					applyToTuple(roundNumber, value:GetComponents())
				)
			end
		end
	elseif valueType == "Rect" then
		return string.format(
			"Rect.new(%s, %s)",
			UIConverterUtils.toLuaPropertyString(value.Min, debugHint),
			UIConverterUtils.toLuaPropertyString(value.Max, debugHint)
		)
	elseif valueType == "ColorSequence" then
		local keypoints = value.Keypoints
		if #keypoints == 1 then
			return string.format(
				"ColorSequence.new(%s)",
				UIConverterUtils.toLuaPropertyString(keypoints[1].Value, debugHint)
			)
		elseif #keypoints == 2 and keypoints[1].Time == 0 and keypoints[2].Time == 1 then
			return string.format(
				"ColorSequence.new(%s, %s)",
				UIConverterUtils.toLuaPropertyString(value.Keypoints[1].Value, debugHint),
				UIConverterUtils.toLuaPropertyString(value.Keypoints[2].Value, debugHint)
			)
		else
			local strings = {}
			for _, keypoint in keypoints do
				table.insert(strings, "\n\t" .. UIConverterUtils.toLuaPropertyString(keypoint, debugHint))
			end
			return string.format("ColorSequence.new({%s\n})", table.concat(strings, ","))
		end
	elseif valueType == "NumberSequence" then
		local keypoints = value.Keypoints
		if #keypoints == 1 then
			return string.format("NumberSequence.new(%s)", roundNumber(keypoints[1].Value))
		elseif #keypoints == 2 and keypoints[1].Time == 0 and keypoints[2].Time == 1 then
			return string.format(
				"NumberSequence.new(%s, %s)",
				roundNumber(keypoints[1].Value),
				roundNumber(keypoints[2].Value)
			)
		else
			local strings = {}
			for _, keypoint in keypoints do
				table.insert(strings, "\n\t" .. UIConverterUtils.toLuaPropertyString(keypoint, debugHint))
			end
			return string.format("NumberSequence.new({%s\n})", table.concat(strings, ","))
		end
	elseif valueType == "ColorSequenceKeypoint" then
		return string.format(
			"ColorSequenceKeypoint.new(%s, %s)",
			roundNumber(value.Time),
			UIConverterUtils.toLuaPropertyString(value.Value, debugHint)
		)
	elseif valueType == "NumberSequenceKeypoint" then
		return string.format(
			"NumberSequenceKeypoint.new(%s, %s)",
			roundNumber(value.Time),
			UIConverterUtils.toLuaPropertyString(value.Value, debugHint)
		)
	elseif valueType == "BrickColor" then
		return string.format("BrickColor.new(%q)", value.Name)
	elseif valueType == "UDim" then
		return string.format("UDim.new(%s, %s)", roundNumber(value.Scale), roundNumber(value.Offset))
	elseif valueType == "UDim2" then
		if value.X.Scale == 0 and value.Y.Scale == 0 and (value.X.Offset ~= 0 or value.Y.Offset ~= 0) then
			return string.format("UDim2.fromOffset(%s, %s)", roundNumber(value.X.Offset), roundNumber(value.Y.Offset))
		elseif value.X.Offset == 0 and value.Y.Offset == 0 and (value.X.Scale ~= 0 or value.Y.Scale ~= 0) then
			return string.format("UDim2.fromScale(%s, %s)", roundNumber(value.X.Scale), roundNumber(value.Y.Scale))
		else
			return string.format(
				"UDim2.new(%s, %s, %s, %s)",
				roundNumber(value.X.Scale),
				roundNumber(value.X.Offset),
				roundNumber(value.Y.Scale),
				roundNumber(value.Y.Offset)
			)
		end
	elseif valueType == "NumberRange" then
		if value.Min == value.Max then
			return string.format("NumberRange.new(%s)", roundNumber(value.Min))
		else
			return string.format("NumberRange.new(%s, %s)", roundNumber(value.Min), roundNumber(value.Max))
		end
	elseif valueType == "EnumItem" then
		return string.format("Enum.%s.%s", tostring(value.EnumType), value.Name)
	elseif valueType == "PhysicalProperties" then
		if value.FrictionWeight == 1 and value.ElasticityWeight == 1 then
			return string.format(
				"PhysicalProperties.new(%s, %s, %s)",
				applyToTuple(roundNumber, value.Density, value.Friction, value.Elasticity)
			)
		else
			return string.format(
				"PhysicalProperties.new(%s, %s, %s, %s, %s)",
				applyToTuple(
					roundNumber,
					value.Density,
					value.Friction,
					value.Elasticity,
					value.FrictionWeight,
					value.ElasticityWeight
				)
			)
		end
	elseif valueType == "Font" then
		if value.Weight == Enum.FontWeight.Regular and value.Style == Enum.FontStyle.Normal then
			return string.format("Font.new(%q)", value.Family)
		else
			return string.format(
				"Font.new(%q, Enum.FontWeight.%s, Enum.FontStyle.%s)",
				value.Family,
				tostring(value.Weight),
				tostring(value.Style)
			)
		end
	elseif valueType == "userdata" then
		-- FontFace
		warn(
			string.format(
				"Bad property type %s for %s - Cannot serialize.",
				valueType,
				debugHint and tostring(debugHint) or "?"
			)
		)
		return "ERROR"
	else
		error(string.format("Unknown property type %s for %s", valueType, debugHint and tostring(debugHint) or "?"))
	end
end

function UIConverterUtils.getRefProperty(refLookupMap, value)
	if refLookupMap[value] then
		return refLookupMap[value]
	else
		return nil -- outside
	end
end

function UIConverterUtils.convertPropertiesToTable(properties, refLookupMap)
	local data = {}
	for key, value in properties do
		if key ~= "Parent" then
			if typeof(value) == "Instance" then
				data[key] = UIConverterUtils.getRefProperty(refLookupMap, value)
			else
				data[key] = UIConverterUtils.toLuaPropertyString(value, key)
			end
		end
	end
	return data
end

function UIConverterUtils.propertiesTableToString(library, properties)
	local keys = {}
	for key, _ in properties do
		table.insert(keys, key)
	end
	table.sort(keys)

	local firstEnsured = 1
	local function ensureFirst(propertyName)
		local index = table.find(keys, propertyName, firstEnsured)
		if index then
			table.remove(keys, index)
			table.insert(keys, firstEnsured, propertyName)
			firstEnsured = firstEnsured + 1
		end
	end
	local function ensureLast(propertyName)
		local index = table.find(keys, propertyName)
		if index then
			table.remove(keys, index)
			table.insert(keys, propertyName)
		end
	end

	ensureFirst("Name")
	ensureFirst("LayoutOrder")
	ensureFirst("Position")
	ensureFirst("AnchorPoint")
	ensureFirst("Size")
	ensureLast(UIConverterUtils.getChildrenKey(library))

	local data = {}
	for _, key in keys do
		table.insert(data, string.format("%s = %s;", key, properties[key]))
	end

	return table.concat(data, "\n")
end

function UIConverterUtils.indent(text: string): string
	local lines = string.split(text, "\n")
	local noEscape = nil

	for key, line in lines do
		if noEscape then
			local pattern = "]" .. noEscape .. "]"
			if line:find(pattern) then
				noEscape = nil
			end
		else
			lines[key] = "\t" .. line

			local index, _, equals = line:find("%[(=*)%[")
			if index then
				noEscape = equals
			end
		end
	end
	return table.concat(lines, "\n")
end

function UIConverterUtils.getChildrenKey(library: UIConverterLibrary): string
	if library == "Blend" then
		return "[Blend.Children]"
	elseif library == "Fusion" then
		return "[Fusion.Children]"
	elseif library == "FusionUnpacked" or library == "BlendUnpacked" then
		return "[Children]"
	else
		error(string.format("Unknown library %q", tostring(library)))
	end
end

function UIConverterUtils.getLibraryNewClass(library: UIConverterLibrary, instance: Instance, propertiesString)
	if library == "Blend" then
		return string.format("Blend.New %q {\n%s\n}", instance.ClassName, propertiesString)
	elseif library == "Fusion" then
		return string.format("Fusion.New %q {\n%s\n}", instance.ClassName, propertiesString)
	elseif library == "FusionUnpacked" or library == "BlendUnpacked" then
		return string.format("New %q {\n%s\n}", instance.ClassName, propertiesString)
	else
		error(string.format("Unknown library %q", tostring(library)))
	end
end

local cachedFusionOverrideMap = nil

function UIConverterUtils.getOverrideMap(library: UIConverterLibrary)
	if library == "Blend" or library == "BlendUnpacked" then
		return require("BlendDefaultProps")
	elseif library == "Fusion" or library == "FusionUnpacked" then
		if cachedFusionOverrideMap then
			return cachedFusionOverrideMap
		end

		-- Little bit of a hack
		local topScript = script:FindFirstAncestorWhichIsA("Script")
		if not topScript then
			error("No top script")
		end

		local blendDefaultProps = topScript:FindFirstChild("BlendDefaultProps", true)
		if not blendDefaultProps then
			error("No blendDefaultProps")
		end

		cachedFusionOverrideMap = require(blendDefaultProps)
		return cachedFusionOverrideMap
	else
		error(string.format("Unknown library %q", tostring(library)))
	end
end

function UIConverterUtils.getSortedChildren(instance: Instance)
	local other = {}
	local guiObjects = {}
	local uiComponents = {}

	for _, child in instance:GetChildren() do
		if child:IsA("UIComponent") then
			table.insert(uiComponents, child)
		elseif child:IsA("GuiObject") then
			local index = 1
			-- stable insertion sort
			for i = 1, #guiObjects do
				if guiObjects[i].LayoutOrder <= child.LayoutOrder then
					index = i + 1
				end
			end

			table.insert(guiObjects, index, child)
		else
			table.insert(other, child)
		end
	end

	local children = {}
	for _, item in uiComponents do
		table.insert(children, item)
	end
	for _, item in guiObjects do
		table.insert(children, item)
	end
	for _, item in other do
		table.insert(children, item)
	end

	return children
end

--[[
	Generates a lookup map that will be used to resolve instances.
]]
function UIConverterUtils.promiseCreateLookupMap(library: UIConverterLibrary, uiConverter, instances)
	assert(type(library) == "string", "Bad library")
	assert(type(uiConverter) == "table", "Bad uiConverter")
	assert(instances, "No instances")

	local needed = {}
	local seen = {}

	local overrideMap = UIConverterUtils.getOverrideMap(library)

	local promises = {}
	local function handleInst(inst)
		seen[inst] = true

		table.insert(
			promises,
			uiConverter:PromiseProperties(inst, overrideMap):Then(function(properties)
				if properties then
					for key, value in properties do
						if key ~= "Parent" then
							if typeof(value) == "Instance" then
								-- TODO: Smarter about this
								needed[value] = key
							end
						end
					end
				end
			end)
		)
	end

	for _, item in instances do
		handleInst(item)
		for _, descendant in item:GetDescendants() do
			handleInst(descendant)
		end
	end

	return PromiseUtils.all(promises):Then(function()
		local lookupMap = {}
		local usedNames = {}

		local function getName(suggestion)
			local name = String.toLowerCamelCase(suggestion)
			if not usedNames[name] then
				return name
			end

			for i = 1, 1000 do
				local newName = name .. tostring(i)
				if not usedNames[newName] then
					return newName
				end
			end

			error("Could not generate a name")
		end

		for item, _ in needed do
			if seen[item] then
				-- TODO: Better algorithm
				local name = getName(item.Name)
				usedNames[name] = true
				lookupMap[item] = name
			end
		end

		return lookupMap
	end)
end

function UIConverterUtils.getLibraryRefEntryKey(library: UIConverterLibrary)
	if library == "Blend" then
		return "[Blend.Instance]"
	elseif library == "BlendUnpacked" then
		return "[Instance]"
	else
		return nil
	end
end

function UIConverterUtils.promiseToLibraryInstance(
	library: UIConverterLibrary,
	uiConverter,
	instance: Instance,
	refLookupMap
)
	assert(type(library) == "string", "Bad library")
	assert(type(uiConverter) == "table", "Bad uiConverter")
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(refLookupMap) == "table", "No refLookupMap")

	return uiConverter
		:PromiseProperties(instance, UIConverterUtils.getOverrideMap(library))
		:Then(function(properties)
			if properties then
			local converted = UIConverterUtils.convertPropertiesToTable(properties, refLookupMap)
			local childrenPromises = {}

				for _, child in UIConverterUtils.getSortedChildren(instance) do
					table.insert(
						childrenPromises,
						UIConverterUtils.promiseToLibraryInstance(library, uiConverter, child, refLookupMap)
					)
				end

				if refLookupMap[instance] then
					local entryKey = UIConverterUtils.getLibraryRefEntryKey(library)
					if entryKey then
						converted[entryKey] = refLookupMap[instance]
					end
				end

				if next(childrenPromises) then
					return PromiseUtils.all(childrenPromises):Then(function(...)
						converted[UIConverterUtils.getChildrenKey(library)] =
							UIConverterUtils.convertListOfItemsToTable({ ... })
						return converted
					end)
				end

				return converted
			else
				return nil
			end
		end)
		:Then(function(properties)
			if properties then
				return UIConverterUtils.getLibraryNewClass(
					library,
					instance,
					UIConverterUtils.indent(UIConverterUtils.propertiesTableToString(library, properties))
				)
			else
				return nil
			end
		end)
end

function UIConverterUtils.getEntryListCode(library: UIConverterLibrary, refLookupMap)
	if not next(refLookupMap) then
		return ""
	end

	if library == "Blend" then
		local items = {}
		for _, value in refLookupMap do
			table.insert(items, string.format("local %s = Blend.State()", value))
		end

		return table.concat(items, "\n") .. "\n\nreturn "
	else
		return ""
	end
end

function UIConverterUtils.convertListOfItemsToTable(results: { string }): string
	local strings = {}
	for _, item in results do
		if item then
			table.insert(strings, item .. ";")
		end
	end
	local childrenText = table.concat(strings, "\n")
	return string.format("{\n%s\n}", UIConverterUtils.indent(childrenText))
end

return UIConverterUtils