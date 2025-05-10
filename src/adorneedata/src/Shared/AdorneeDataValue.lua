--[=[
	Allows access to an attribute like a ValueObject but in table form.

	```lua
	local data = AdorneeDataValue.new(workspace, {
		Version = "1.0.0";
		CFrame = CFrame.new();
	})
	print(data.Version.Value) --> 1.0.0
	print(workspace:GetAttribute("version")) --> 1.0.0

	data.Version.Changed:Connect(function()
		print(data.Version.Value)
	end)

	workspace:SetAttribute("1.1.0") --> 1.1.0
	data.Value = "1.2.0" --> 1.2.0
	```

	@class AdorneeDataValue
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeDataEntry = require("AdorneeDataEntry")
local AttributeValue = require("AttributeValue")
local Rx = require("Rx")
local RxSignal = require("RxSignal")

local AdorneeDataValue = {}
AdorneeDataValue.ClassName = "AdorneeDataValue"
AdorneeDataValue.__index = AdorneeDataValue

--[=[
	Constructs a new AdorneeDataValue

	@param adornee Instance
	@param prototype table
	@return AdorneeDataValue<T>
]=]
function AdorneeDataValue.new(adornee, prototype)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(prototype) == "table", "Bad prototype")

	local self = {
		_adornee = adornee,
		_defaultValues = prototype,
		_valueObjects = {},
	}

	for key, value in prototype do
		if AdorneeDataEntry.isAdorneeDataEntry(value) then
			self._valueObjects[key] = value:Create(adornee)
		else
			self._valueObjects[key] = AttributeValue.new(adornee, key, value)
		end
	end

	return setmetatable(self, AdorneeDataValue)
end

--[=[
	The current property of the Attribute. Can be assigned to to write
	the attribute.
	@prop Value T
	@within AdorneeDataValue
]=]

--[=[
	Signal that fires when the attribute changes
	@readonly
	@prop Changed Signal<()>
	@within AdorneeDataValue
]=]
function AdorneeDataValue:__index(index)
	if index == "Value" then
		local result = {}
		for key, valueObject in self._valueObjects do
			result[key] = valueObject.Value
		end
		return result
	elseif index == "Changed" then
		return RxSignal.new(self:Observe():Pipe({
			Rx.skip(1),
		}))
	elseif AdorneeDataValue[index] then
		return AdorneeDataValue[index]
	elseif type(index) == "string" then
		local attributeValues = rawget(self, "_valueObjects")
		if attributeValues[index] then
			return attributeValues[index]
		else
			error(string.format("%q is not a member of AdorneeDataValue", tostring(index)))
		end
	else
		error(string.format("%q is not a member of AdorneeDataValue", tostring(index)))
	end
end

--[=[
	Observes an attribute on an instance.
	@return Observable<any>
]=]
function AdorneeDataValue:Observe()
	local current = rawget(self, "_defaultObservable")
	if current then
		return current
	end

	local attributeValues = rawget(self, "_valueObjects")

	local observables = {}
	for key, valueObject in attributeValues do
		observables[key] = valueObject:Observe()
	end

	local observable = Rx.combineLatest(observables)
	rawset(self, "_defaultObservable", observable)
	return observable
end

function AdorneeDataValue:__newindex(index, newValue)
	if index == "Value" then
		assert(type(newValue) == "table", "Bad newValue")
		local attributeValues = rawget(self, "_valueObjects")

		for key, value in newValue do
			if attributeValues[key] then
				attributeValues[key].Value = value
			else
				error("%s is not a valid member of AttributeValue")
			end
		end
	else
		error(string.format("Use AttributeValue.%q.Value to set an attribute", tostring(index)))
	end
end

function AdorneeDataValue:_getOrCreateAttributeValue(key)
	local attributeValues = rawget(self, "_valueObjects")
	if attributeValues[key] then
		return attributeValues[key]
	else
		local prototype = rawget(self, "_defaultValues")
		local adornee = rawget(self, "_adornee")

		attributeValues[key] = AttributeValue.new(adornee, key, prototype[key])
		return attributeValues
	end
end

return AdorneeDataValue
