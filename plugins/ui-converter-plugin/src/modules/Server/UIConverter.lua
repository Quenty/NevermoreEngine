--[=[
	@class UIConverter
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Color3Utils = require("Color3Utils")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local RobloxApiDump = require("RobloxApiDump")
local UIConverterNeverSkipProps = require("UIConverterNeverSkipProps")

local UIConverter = setmetatable({}, BaseObject)
UIConverter.ClassName = "UIConverter"
UIConverter.__index = UIConverter

function UIConverter.new()
	local self = setmetatable(BaseObject.new(), UIConverter)

	self._apiDump = RobloxApiDump.new()
	self._maid:GiveTask(self._apiDump)

	self._promiseDefaultValueCache = {}
	self._propertyPromisesForClass = {}

	return self
end

function UIConverter:PromiseProperties(instance, overrideMap)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(overrideMap) == "table", "Bad overrideMap")

	return self._apiDump:PromiseClass(instance.ClassName)
		:Then(function(class)
			if class:IsService() then
				-- TODO: Mount here
				return Promise.rejected(string.format("%q is a service and cannot be created", class:GetClassName()))
			end

			if class:IsNotCreatable() then
				-- Just don't include this
				return Promise.resolved(nil)
			end

			return self._maid:GivePromise(self:PromisePropertiesForClass(class:GetClassName()))
				:Then(function(properties)
					local map = {}
					local promises = {}

					local hasProperties = {}

			for _, property in properties do
				hasProperties[property:GetName()] = true

				self._maid
					:GivePromise(self:PromiseDefaultValue(class, property, overrideMap))
					:Then(function(defaultValue)
						local currentValue = instance[property:GetName()]
						if currentValue ~= defaultValue then
							map[property:GetName()] = currentValue
						end
					end)
			end

			-- Make sure we also include these properties for authoring
			local neverSkip = UIConverterNeverSkipProps[class:GetClassName()]
			if neverSkip then
				for propertyName, _ in neverSkip do
					map[propertyName] = instance[propertyName]
				end
			end

			return PromiseUtils.all(promises):Then(function()
				-- Specifically handle edge-case with border size pixel defaults in the assumption of superfluous
				-- border properties
				-- TODO: Could group this all under a "PropertyObscuresOtherPropertyUnderCondition" scenario
				-- TODO: also need to remove in case of UICorner or other scenarios
				if hasProperties["BackgroundTransparency"] and instance.BackgroundTransparency >= 1 then
					if hasProperties["BorderSizePixel"] and instance.BorderSizePixel == 1 then
						map.BorderSizePixel = nil
					end

					if
						hasProperties["BorderColor3"]
						and Color3Utils.areEqual(instance.BorderColor3, Color3.fromRGB(27, 42, 53))
					then
						map.BorderColor3 = nil
					end
				end

				return map
			end)
				end)

		end)
end

function UIConverter:PromiseCanClone(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	return self._apiDump:PromiseClass(instance.ClassName):Then(function(class)
		return not class:IsNotCreatable()
	end)
end

function UIConverter:PromisePropertiesForClass(className: string)
	assert(type(className) == "string", "Bad className")

	if self._propertyPromisesForClass[className] then
		return self._propertyPromisesForClass[className]
	end

	self._propertyPromisesForClass[className] = self._maid:GivePromise(self._apiDump:PromiseClass(className))
		:Then(function(class)
		return class:PromiseProperties()
		end)
		:Then(function(allProperties)
		local valid = {}
			for _, property in allProperties do
				if not (property:IsHidden()
						or property:IsReadOnly()
						or property:IsNotScriptable()
						or property:IsDeprecated()
						or property:IsWriteNotAccessibleSecurity()
						or property:IsReadNotAccessibleSecurity()
						or property:IsWriteLocalUserSecurity()
						or property:IsReadLocalUserSecurity()
						or property:IsWriteRobloxScriptSecurity()
						or property:IsReadRobloxScriptSecurity())
					then

					table.insert(valid, property)
				end
			end
			return valid
		end)
	return self._propertyPromisesForClass[className]
end

function UIConverter:PromiseDefaultValue(class, property, overrideMap)
	assert(type(class) == "table", "Bad class")
	assert(type(property) == "table", "Bad property")
	assert(type(overrideMap) == "table", "Bad overrideMap")

	local propertyName = property:GetName()
	local className = class:GetClassName()

	if property:IsReadLocalUserSecurity() then
		return Promise.resolved(nil)
	end

	if class:IsNotCreatable() then
		return Promise.resolved(nil)
	end

	local classCache = self._promiseDefaultValueCache[className]
	if not classCache then
		classCache = {}
		self._promiseDefaultValueCache[className] = classCache
	end

	if not classCache[propertyName] then
		classCache[propertyName] = {}
	end

	-- check cache for override map
	if classCache[propertyName][overrideMap] then
		return classCache[propertyName][overrideMap]
	end

	-- check cache for default
	if classCache[propertyName].default then
		return classCache[propertyName].default
	end

	-- check override map first
	local properties = overrideMap[class:GetClassName()]
	if properties and properties[propertyName] then
		classCache[propertyName][overrideMap] = Promise.resolved(properties[propertyName])
		return classCache[propertyName][overrideMap]
	end

	-- then check default
	local inst = Instance.new(className)
	classCache[propertyName].default = Promise.resolved(inst[propertyName])
	inst:Destroy()

	return classCache[propertyName].default
end


return UIConverter
