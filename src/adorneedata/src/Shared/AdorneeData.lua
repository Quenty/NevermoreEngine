--[=[
	Bridges attributes and serializable data table. It's typical to need to define data in 3 ways.

	1. Attributes on an instance for replication
	2. Tables for Lua configuration
	3. Within AttributeValues for writing regular code

	Providing all 3

	## Usage
	Here's how the usage works:

	```lua
	-- Store data somewhere central

	return AdorneeData.new({
		EnableCombat = true;
		PunchDamage = 15;
	})
	```

	You can then use the data to retrieve values

	```lua
	local data = CombatConfiguration:Create(workspace)

	-- Can ready any data
	print(data.EnableCombat.Value) --> true
	print(data.PunchDamage.Value) --> 15
	print(data.Value) --> { EnableCombat = true, PunchDamage = true }

	-- Can write any data
	data.EnableCombat.Value = false
	data.PunchDamage.Value = 15
	data.Value = {
		EnableCombat = false;
		PunchDamage = 150;
	}

	-- Can subscribe to the data
	data.EnableCombat:Observe():Subscribe(print)
	data.PunchDamage:Observe():Subscribe(print)
	data:Observe():Subscribe(print)

	-- Can also operate without creating a value (although creating value is cheap)
	local punchDamage = CombatConfiguration.PunchDamage:Create(workspace)
	punchDamage.Value = 20
	punchDamage:Observe():Subscribe(print)

	-- Or like this
	CombatConfiguration.PunchDamage:SetValue(workspace, 25)
	print(CombatConfiguration.PunchDamage:GetValue(workspace))
	CombatConfiguration.PunchDamage:Observe(workspace):Subscribe(print)

	-- You can also create validated data
	local defaultCombatState = CombatConfiguration:CreateData({
		EnableCombat = true;
		PunchDamage = 15;
	})

	-- Or validate that the data you're getting is valid
	assert(CombatConfiguration:IsData(defaultCombatState))

	-- Or read attributes directly
	CombatConfiguration:Get(workspace))

	-- Note that this is the same as an attribute
	print(workspace:GetAttribute("EnableCombat")) --> true
	```

	@class AdorneeData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeDataEntry = require("AdorneeDataEntry")
local AdorneeDataValue = require("AdorneeDataValue")
local AttributeUtils = require("AttributeUtils")
local AttributeValue = require("AttributeValue")
local t = require("t")

local AdorneeData = {}
AdorneeData.ClassName = "AdorneeData"
AdorneeData.__index = AdorneeData

--[=[
	Attribute data specification

	@param prototype any
	@return AdorneeData<T>
]=]
function AdorneeData.new(prototype: any)
	local self = setmetatable({}, AdorneeData)

	self._fullPrototype = assert(prototype, "Bad prototype")
	self._attributePrototype = {}
	self._defaultValuesPrototype = {}
	self._valueObjectPrototype = {}

	for key, item in self._fullPrototype do
		if AdorneeDataEntry.isAdorneeDataEntry(item) then
			local default = item:GetDefaultValue()
			self._defaultValuesPrototype[key] = default
			self._valueObjectPrototype[key] = item
		else
			self._defaultValuesPrototype[key] = item
			self._attributePrototype[key] = item
		end
	end

	return self
end

function AdorneeData:__index(index)
	if AdorneeData[index] then
		return AdorneeData[index]
	elseif type(index) == "string" then
		local found = self._fullPrototype[index]
		if found == nil then
			error(string.format("[AdorneeData] - Bad index %q is not a known attribute name", index))
		end

		if AdorneeDataEntry.isAdorneeDataEntry(found) then
			return found
		else
			-- TODO: Cache this construction
			return AdorneeDataEntry.new(typeof(found), function(adornee)
				return AttributeValue.new(adornee, index, found)
			end, found)
		end
	else
		error("Bad index")
	end
end

--[=[
	Returns true if the data is valid data, otherwise returns false and an error.

	@param data any
	@return boolean
	@return string -- Error message
]=]
function AdorneeData:IsStrictData(data): (boolean, string?)
	return self:GetStrictTInterface()(data)
end

--[=[
	Validates and creates a new data table for the data that is readonly and frozen

	@param data TStrict
	@return TStrict
]=]
function AdorneeData:CreateStrictData(data)
	assert(self:IsStrictData(data))

	return table.freeze(table.clone(data))
end

--[=[
	Validates and creates a new data table that is readonly. This table will have all values or
	the defaults

	@param data T
	@return T
]=]
function AdorneeData:CreateFullData(data)
	assert(self:IsData(data))

	local result = table.clone(self._defaultValuesPrototype)

	for key, value in data do
		result[key] = value
	end

	return table.freeze(table.clone(result))
end

--[=[
	Validates and creates a new data table that is readonly and frozen, but for partial
	data.

	The  data can just be part of the attributes.

	@param data TPartial
	@return TPartial
]=]
function AdorneeData:CreateData(data)
	assert(self:IsData(data))

	return table.freeze(table.clone(data))
end

--[=[
	Observes the attribute table for adornee

	@param adornee Instance
	@return Observable<TStrict>
]=]
function AdorneeData:Observe(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self:Create(adornee):Observe(adornee)
end

--[=[
	Gets attribute table for the data

	@param adornee Instance
	@return AdorneeDataValue
]=]
function AdorneeData:Create(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local attributeTableValue = AdorneeDataValue.new(adornee, self._fullPrototype)

	return attributeTableValue
end

--[=[
	Gets the attributes for the adornee

	@param adornee Instance
	@return TStrict
]=]
function AdorneeData:Get(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local data = {}
	for key, defaultValue in self._attributePrototype do
		local result = adornee:GetAttribute(key)
		if result == nil then
			result = defaultValue
		end
		data[key] = result
	end

	-- TODO: Avoid additional allocation
	for key, value in self._valueObjectPrototype do
		data[key] = value:Create(adornee).Value
	end

	return self:CreateStrictData(data)
end

--[=[
	Sets the attributes for the adornee

	@param adornee Instance
	@param data T
]=]
function AdorneeData:Set(adornee: Instance, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	local attributeTable = self:Create(adornee)
	for key, value in data do
		attributeTable[key].Value = value
	end
end

--[=[
	Unsets the adornee's attributes (only for baseline attributes)

	@param adornee Instance
]=]
function AdorneeData:Unset(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	for key, _ in self._attributePrototype do
		adornee:SetAttribute(key, nil)
	end

	-- TODO: Unset value object values
end

--[=[
	Sets the attributes for the adornee

	@param adornee Instance
	@param data TStrict
]=]
function AdorneeData:SetStrict(adornee: Instance, data)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsStrictData(data))

	for key, _ in self._attributePrototype do
		adornee:SetAttribute(key, data[key])
	end

	-- TODO: Avoid additional allocation
	for key, value in self._valueObjectPrototype do
		value:Create(adornee).Value = data[key]
	end
end

--[=[
	Initializes the attributes for the adornee

	@param adornee Instance
	@param data T?
]=]
function AdorneeData:InitAttributes(adornee: Instance, data)
	data = data or {}
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self:IsData(data))

	for key, defaultValue in self._attributePrototype do
		if adornee:GetAttribute(key) == nil then
			if data[key] ~= nil then
				adornee:SetAttribute(key, data[key])
			else
				adornee:SetAttribute(key, defaultValue)
			end
		end
	end

	-- TODO: Avoid additional allocation
	for key, value in self._valueObjectPrototype do
		local valueObject = value:Create(adornee)
		if valueObject == nil then
			if data[key] ~= nil then
				valueObject.Value = data[key]
			end
		end
	end
end

AdorneeData.GetAttributes = AdorneeData.Get
AdorneeData.SetAttributes = AdorneeData.Set
AdorneeData.CreateAdorneeDataValue = AdorneeData.Create
AdorneeData.CreateValue = AdorneeData.Create
AdorneeData.SetStrictAttributes = AdorneeData.SetStrict

--[=[
	Gets a strict interface which will return true if the value is a partial interface and
	false otherwise.

	@return function
]=]
function AdorneeData:GetStrictTInterface()
	local found = rawget(self, "_fullInterface")
	if found then
		return found
	end

	self._fullInterface = t.strictInterface(self:_getOrCreateTypeInterfaceList())
	return self._fullInterface
end

--[=[
	Gets a [t] interface which will return true if the value is a partial interface, and
	false otherwise.

	@return function
]=]
function AdorneeData:GetTInterface()
	local found = rawget(self, "_interface")
	if found then
		return found
	end

	local interfaceList = {}
	for key, value in pairs(self:_getOrCreateTypeInterfaceList()) do
		interfaceList[key] = t.optional(value)
	end

	self._interface = t.strictInterface(interfaceList)
	return self._interface
end

--[=[
	Returns true if the data is valid partial data, otherwise returns false and an error.

	@param data any
	@return boolean
	@return string -- Error message
]=]
function AdorneeData:IsData(data)
	return self:GetTInterface()(data)
end

function AdorneeData:_getOrCreateTypeInterfaceList()
	local found = rawget(self, "_typeInterfaceList")
	if found then
		return found
	end

	local interfaceList = {}

	for key, value in self._fullPrototype do
		if AdorneeDataEntry.isAdorneeDataEntry(value) then
			interfaceList[key] = value:GetStrictInterface()
		else
			local valueType = typeof(value)
			assert(AttributeUtils.isValidAttributeType(valueType), "Not a valid value type")

			interfaceList[key] = t.typeof(valueType)
		end
	end

	self._typeInterfaceList = interfaceList
	return interfaceList
end

return AdorneeData
