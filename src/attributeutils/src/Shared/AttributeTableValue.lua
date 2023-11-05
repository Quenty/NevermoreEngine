--[=[
	Allows access to an attribute like a ValueObject but in table form.

	```lua
	local attributeValue = AttributeTableValue.new(workspace, {
		Version = "1.0.0";
		CFrame = CFrame.new();
	})
	print(attributeValue.Version.Value) --> 1.0.0
	print(workspace:GetAttribute("version")) --> 1.0.0

	attributeValue.Version.Changed:Connect(function()
		print(attributeValue.Version.Value)
	end)

	workspace:SetAttribute("1.1.0") --> 1.1.0
	attributeValue.Value = "1.2.0" --> 1.2.0
	```

	@class AttributeTableValue
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local RxSignal = require("RxSignal")
local Rx = require("Rx")

local AttributeTableValue = {}
AttributeTableValue.ClassName = "AttributeTableValue"
AttributeTableValue.__index = AttributeTableValue

--[=[
	Constructs a new AttributeTableValue

	@param adornee Instance
	@param defaultValues table
	@return AttributeTableValue<T>
]=]
function AttributeTableValue.new(adornee, defaultValues)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(type(defaultValues) == "table", "Bad defaultValues")

	local self = {
		_adornee = adornee;
		_defaultValues = defaultValues;
		_attributeValues = {};
	}

	for key, value in pairs(defaultValues) do
		self._attributeValues[key] = AttributeValue.new(adornee, key, value)
	end

	return setmetatable(self, AttributeTableValue)
end

--[=[
	The current property of the Attribute. Can be assigned to to write
	the attribute.
	@prop Value T
	@within AttributeTableValue
]=]

--[=[
	Signal that fires when the attribute changes
	@readonly
	@prop Changed Signal<()>
	@within AttributeTableValue
]=]
function AttributeTableValue:__index(index)
	if index == "Value" then
		local result = {}
		for key, attributeValue in pairs(self._attributeValues) do
			result[key] = attributeValue.Value
		end
		return result
	elseif index == "Changed" then
		return RxSignal.new(self:Observe():Pipe({
			Rx.skip(1);
		}))
	elseif AttributeTableValue[index] then
		return AttributeTableValue[index]
	elseif type(index) == "string" then
		local attributeValues = rawget(self, "_attributeValues")
		if attributeValues[index] then
			return attributeValues[index]
		else
			error(string.format("%q is not a member of AttributeTableValue", tostring(index)))
		end
	else
		error(string.format("%q is not a member of AttributeTableValue", tostring(index)))
	end
end

--[=[
	Observes an attribute on an instance.
	@return Observable<any>
]=]
function AttributeTableValue:Observe()
	local current = rawget(self, "_defaultObservable")
	if current then
		return current
	end

	local attributeValues = rawget(self, "_attributeValues")

	local observables = {}
	for key, attributeValue in pairs(attributeValues) do
		observables[key] = attributeValue:Observe()
	end

	local observable = Rx.combineLatest(observables)
	rawset(self, "_defaultObservable", observable)
	return observable
end

function AttributeTableValue:__newindex(index, newValue)
	if index == "Value" then
		assert(type(newValue) == "table", "Bad newValue")
		local attributeValues = rawget(self, "_attributeValues")

		for key, value in pairs(newValue) do
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

function AttributeTableValue:_getOrCreateAttributeValue(key)
	local attributeValues = rawget(self, "_attributeValues")
	if attributeValues[key] then
		return attributeValues[key]
	else
		local defaultValues = rawget(self, "_defaultValues")
		local adornee = rawget(self, "_adornee")

		attributeValues[key] = AttributeValue.new(adornee, key, defaultValues[key])
		return attributeValues
	end
end

return AttributeTableValue