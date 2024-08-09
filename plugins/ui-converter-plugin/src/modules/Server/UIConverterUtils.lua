--[=[
	@class UIConverterUtils
]=]

local require = require(script.Parent.loader).load(script)

local PromiseUtils = require("PromiseUtils")
local Math = require("Math")
local String = require("String")

local UIConverterUtils = {}

local function applyToTuple(func, ...)
	local result = {}
	for _, item in pairs({...}) do
		table.insert(result, func(item))
	end
	return unpack(result)
end

local function roundNumber(value)
	if value == math.huge then
		return "math.huge"
	elseif value == -math.huge then
		return "-math.huge"
	else
		local formatted = string.format("%0.6f", value)
		local stripped = formatted:gsub("%.?0+$", "")

		return stripped
	end
end

local function roundToPi(value)
	local closeTo = Math.round(value/math.pi, 1e-6)
	if closeTo == 0 then
		return "0"
	elseif closeTo == -1 then
		return "-math.pi"
	elseif closeTo == 1 then
		return "math.pi"
	else
		local fractionBottom = Math.round(math.pi/value, 1e-6)
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

function UIConverterUtils.toMultiLineEscape(text)
	if text:find("\n") then
		for i=0, 250 do
			local equals = ("="):rep(i)
			local sep = string.format("%%[%s%%[", equals)
			local endSep = string.format("%%]%s%%]", equals)

			if not text:find(sep) and not text:find(endSep) then
				return string.format("%s%s%s", string.format("[%s[", equals), text, string.format("]%s]", equals))
			end
		end
		return string.format("[[%s]]", text)
	end
end

function UIConverterUtils.toLuaComment(text)
	if text:find("\n") then
		return "--" .. UIConverterUtils.toMultiLineEscape("\n" .. text .. "\n")
	else
		return "-- " .. text
	end
end

function UIConverterUtils.toLuaPropertyString(value, debugHint)
	local valueType = typeof(value)
	if valueType == "string" then
		local multiline = UIConverterUtils.toMultiLineEscape(value)
		if multiline then
			return multiline
		else
			return ("%q"):format(value)
		end
	elseif valueType == "number" then
		return roundNumber(value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "Color3" then
		return ("Color3.fromRGB(%d, %d, %d)"):format(value.R*255, value.G*255, value.B*255)
	elseif valueType == "Vector2" then
		return ("Vector2.new(%s, %s)"):format(applyToTuple(roundNumber, value.x, value.y))
	elseif valueType == "Vector3" then
		return ("Vector3.new(%s, %s, %s)"):format(applyToTuple(roundNumber, value.x, value.y, value.z))
	elseif valueType == "CFrame" then
		if value.Rotation == CFrame.new() then
			return ("CFrame.new(%s, %s, %s)"):format(applyToTuple(roundNumber, value.x, value.y, value.z))
		elseif value.x == 0 and value.y == 0 and value.z == 0 then
			local x, y, z = value:toEulerAnglesXYZ()
			return ("CFrame.Angles(%s, %s, %s)"):format(applyToTuple(roundNumber, x, y, z))
		else
			local x, y, z = value:toEulerAnglesXYZ()
			local roundX, roundY, roundZ = roundToPi(x), roundToPi(y), roundToPi(z)

			if roundX and roundY and roundZ then
				return ("CFrame.new(%s, %s, %s) * CFrame.Angles(%s, %s, %s)")
					:format(
						roundNumber(value.x),
						roundNumber(value.y),
						roundNumber(value.z),
						roundX,
						roundY,
						roundZ)
			else
				return ("CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"):format(
					applyToTuple(roundNumber, value:components()))
			end
		end
	elseif valueType == "Rect" then
		return ("Rect.new(%s, %s)"):format(
			UIConverterUtils.toLuaPropertyString(value.Min, debugHint),
			UIConverterUtils.toLuaPropertyString(value.Max, debugHint))
	elseif valueType == "ColorSequence" then
		local keypoints = value.Keypoints
		if #keypoints == 1 then
			return ("ColorSequence.new(%s)"):format(UIConverterUtils.toLuaPropertyString(keypoints[1].Value, debugHint))
		elseif #keypoints == 2 and keypoints[1].Time == 0 and keypoints[2].Time == 1 then
			return ("ColorSequence.new(%s, %s)"):format(
				UIConverterUtils.toLuaPropertyString(value.Keypoints[1].Value, debugHint),
				UIConverterUtils.toLuaPropertyString(value.Keypoints[2].Value, debugHint))
		else
			local strings = {}
			for _, keypoint in pairs(keypoints) do
				table.insert(strings, "\n\t" .. UIConverterUtils.toLuaPropertyString(keypoint, debugHint))
			end
			return ("ColorSequence.new({%s\n})"):format(table.concat(strings, ","))
		end
	elseif valueType == "NumberSequence" then
		local keypoints = value.Keypoints
		if #keypoints == 1 then
			return ("NumberSequence.new(%s)"):format(roundNumber(keypoints[1].Value))
		elseif #keypoints == 2 and keypoints[1].Time == 0 and keypoints[2].Time == 1 then
			return ("NumberSequence.new(%s, %s)"):format(
				roundNumber(keypoints[1].Value),
				roundNumber(keypoints[2].Value))
		else
			local strings = {}
			for _, keypoint in pairs(keypoints) do
				table.insert(strings, "\n\t" .. UIConverterUtils.toLuaPropertyString(keypoint, debugHint))
			end
			return ("NumberSequence.new({%s\n})"):format(table.concat(strings, ","))
		end
	elseif valueType == "ColorSequenceKeypoint" then
		return ("ColorSequenceKeypoint.new(%s, %s)"):format(
			roundNumber(value.Time),
			UIConverterUtils.toLuaPropertyString(value.Value, debugHint))
	elseif valueType == "NumberSequenceKeypoint" then
		return ("NumberSequenceKeypoint.new(%s, %s)"):format(
			roundNumber(value.Time),
			UIConverterUtils.toLuaPropertyString(value.Value, debugHint))
	elseif valueType == "BrickColor" then
		return ("BrickColor.new(%q)"):format(value.Name)
	elseif valueType == "UDim" then
		return ("UDim.new(%s, %s)"):format(roundNumber(value.Scale), roundNumber(value.Offset))
	elseif valueType == "UDim2" then
		if value.X.Scale == 0 and value.Y.Scale == 0 and
			(value.X.Offset ~= 0 or value.Y.Offset ~= 0) then
			return ("UDim2.fromOffset(%s, %s)"):format(roundNumber(value.X.Offset), roundNumber(value.Y.Offset))
		elseif value.X.Offset == 0 and value.Y.Offset == 0
			and (value.X.Scale ~= 0 or value.Y.Scale ~= 0) then
			return ("UDim2.fromScale(%s, %s)"):format(roundNumber(value.X.Scale), roundNumber(value.Y.Scale))
		else
			return ("UDim2.new(%s, %s, %s, %s)"):format(
				roundNumber(value.X.Scale), roundNumber(value.X.Offset), roundNumber(value.Y.Scale), roundNumber(value.Y.Offset))
		end
	elseif valueType == "NumberRange" then
		if value.Min == value.Max then
			return ("NumberRange.new(%s)"):format(roundNumber(value.Min))
		else
			return ("NumberRange.new(%s, %s)"):format(roundNumber(value.Min), roundNumber(value.Max))
		end
	elseif valueType == "EnumItem" then
		return ("Enum.%s.%s"):format(tostring(value.EnumType), value.Name)
	elseif valueType == "PhysicalProperties" then
		if value.FrictionWeight == 1 and value.ElasticityWeight == 1 then
			return ("PhysicalProperties.new(%s, %s, %s)"):format(
				applyToTuple(roundNumber, value.Density, value.Friction, value.Elasticity))
		else
			return ("PhysicalProperties.new(%s, %s, %s, %s, %s)"):format(
				applyToTuple(roundNumber, value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight))
		end
	elseif valueType == "Font" then
		if value.Weight == Enum.FontWeight.Regular and value.Style == Enum.FontStyle.Normal then
			return ("Font.new(%q)"):format(value.Family)
		else
			return ("Font.new(%q, %s, %s)"):format(value.Family, tostring(value.Weight), tostring(value.Style))
		end
	elseif valueType == "userdata" then
		-- FontFace
		warn(("Bad property type %s for %s - Cannot serialize."):format(valueType, debugHint and tostring(debugHint) or "?"))
	else
		error(("Unknown property type %s for %s"):format(valueType, debugHint and tostring(debugHint) or "?"))
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
	for key, value in pairs(properties) do
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
	for key, _ in pairs(properties) do
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
	ensureLast(UIConverterUtils.getChildrenKey(library));

	local data = {}
	for _, key in pairs(keys) do
		table.insert(data, ("%s = %s;"):format(key, properties[key]))
	end

	return table.concat(data, "\n")
end

function UIConverterUtils.indent(text)
	local lines = string.split(text, "\n")
	local noEscape = nil

	for key, line in pairs(lines) do
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

function UIConverterUtils.getChildrenKey(library)
	if library == "Blend" then
		return "[Blend.Children]"
	elseif library == "Fusion" then
		return "[Fusion.Children]"
	elseif library == "FusionUnpacked" or library == "BlendUnpacked" then
		return "[Children]"
	else
		error(("Unknown library %q"):format(tostring(library)))
	end
end

function UIConverterUtils.getLibraryNewClass(library, instance, propertiesString)
	if library == "Blend" then
		return ("Blend.New %q {\n%s\n}"):format(instance.ClassName, propertiesString)
	elseif library == "Fusion" then
		return ("Fusion.New %q {\n%s\n}"):format(instance.ClassName, propertiesString)
	elseif library == "FusionUnpacked" or library == "BlendUnpacked" then
		return ("New %q {\n%s\n}"):format(instance.ClassName, propertiesString)
	else
		error(("Unknown library %q"):format(tostring(library)))
	end
end

local cachedFusionOverrideMap = nil

function UIConverterUtils.getOverrideMap(library)
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
		error(("Unknown library %q"):format(tostring(library)))
	end
end

function UIConverterUtils.getSortedChildren(instance)
	local other = {}
	local guiObjects = {}
	local uiComponents = {}

	for _, child in pairs(instance:GetChildren()) do
		if child:IsA("UIComponent") then
			table.insert(uiComponents, child)
		elseif child:IsA("GuiObject") then
			local index = 1
			-- stable insertion sort
			for i=1, #guiObjects do
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
	for _, item in pairs(uiComponents) do
		table.insert(children, item)
	end
	for _, item in pairs(guiObjects) do
		table.insert(children, item)
	end
	for _, item in pairs(other) do
		table.insert(children, item)
	end

	return children
end

--[[
	Generates a lookup map that will be used to resolve instances.
]]
function UIConverterUtils.promiseCreateLookupMap(library, uiConverter, instances)
	assert(type(library) == "string", "Bad library")
	assert(type(uiConverter) == "table", "Bad uiConverter")
	assert(instances, "No instances")

	local needed = {}
	local seen = {}

	local overrideMap = UIConverterUtils.getOverrideMap(library)

	local promises = {}
	local function handleInst(inst)
		seen[inst] = true

		table.insert(promises, uiConverter:PromiseProperties(inst, overrideMap)
			:Then(function(properties)
				if properties then
					for key, value in pairs(properties) do
						if key ~= "Parent" then
							if typeof(value) == "Instance" then
								-- TODO: Smarter about this
								needed[value] = key
							end
						end
					end
				end
			end))
	end

	for _, item in pairs(instances) do
		handleInst(item)
		for _, descendant in pairs(item:GetDescendants()) do
			handleInst(descendant)
		end
	end


	return PromiseUtils.all(promises)
		:Then(function()
			local lookupMap = {}
			local usedNames = {}

			local function getName(suggestion)
				local name = String.toLowerCamelCase(suggestion)
				if not usedNames[name] then
					return name
				end

				for i=1, 1000 do
					local newName = name .. tostring(i)
					if not usedNames[newName] then
						return newName
					end
				end

				error("Could not generate a name")
			end

			for item, _ in pairs(needed) do
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

function UIConverterUtils.getLibraryRefEntryKey(library)
	if library == "Blend" then
		return "[Blend.Instance]"
	elseif library == "BlendUnpacked" then
		return "[Instance]"
	else
		return nil
	end
end

function UIConverterUtils.promiseToLibraryInstance(library, uiConverter, instance, refLookupMap)
	assert(type(library) == "string", "Bad library")
	assert(type(uiConverter) == "table", "Bad uiConverter")
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(refLookupMap) == "table", "No refLookupMap")

	return uiConverter:PromiseProperties(instance, UIConverterUtils.getOverrideMap(library))
		:Then(function(properties)
			if properties then
				local converted = UIConverterUtils.convertPropertiesToTable(properties, refLookupMap)
				local childrenPromises = {}

				for _, child in pairs(UIConverterUtils.getSortedChildren(instance)) do
					table.insert(childrenPromises, UIConverterUtils.promiseToLibraryInstance(library, uiConverter, child, refLookupMap))
				end

				if refLookupMap[instance] then
					local entryKey = UIConverterUtils.getLibraryRefEntryKey(library)
					if entryKey then
						converted[entryKey] = refLookupMap[instance]
					end
				end

				if next(childrenPromises) then
					return PromiseUtils.all(childrenPromises)
						:Then(function(...)
							converted[UIConverterUtils.getChildrenKey(library)] = UIConverterUtils.convertListOfItemsToTable({...})
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
					UIConverterUtils.indent(UIConverterUtils.propertiesTableToString(library, properties)))
			else
				return nil
			end
		end)
end

function UIConverterUtils.getEntryListCode(library, refLookupMap)
	if not next(refLookupMap) then
		return ""
	end

	if library == "Blend" then
		local items = {}
		for _, value in pairs(refLookupMap) do
			table.insert(items, ("local %s = Blend.State()"):format(value))
		end

		return table.concat(items, "\n") .. "\n\nreturn "
	else
		return ""
	end
end

function UIConverterUtils.convertListOfItemsToTable(results)
	local strings = {}
	for _, item in pairs(results) do
		if item then
			table.insert(strings, item .. ";")
		end
	end
	local childrenText = table.concat(strings, "\n")
	return ("{\n%s\n}"):format(UIConverterUtils.indent(childrenText))
end

return UIConverterUtils
