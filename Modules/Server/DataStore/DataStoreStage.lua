--- Provides a data storage facility with an ability to get sub-stores. So you can write
-- directly to this store, overwriting all children, or you can have more partial control
-- at children level. This minimizes accidently overwriting.
-- The big cost here is that we may leave keys that can't be removed.
-- @classmod DataStoreStage

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Table = require("Table")
local DataStoreWriter = require("DataStoreWriter")

local DataStoreStage = setmetatable({}, BaseObject)
DataStoreStage.ClassName = "DataStoreStage"
DataStoreStage.__index = DataStoreStage

function DataStoreStage.new()
	local self = setmetatable(BaseObject.new(), DataStoreStage)

	self._takenKeys = {} -- [name] = true
	self._stores = {}

	return self
end

function DataStoreStage:Store(name, value)
	if self._takenKeys[name] then
		error(("[DataStoreStage] - Already have a writer for %q"):format(name))
	end

	self:_doStore(name, value)
end

function DataStoreStage:GetSubStore(name)
	assert(type(name) == "string")

	if self._stores[name] then
		return self._stores[name]
	end

	if self._takenKeys[name] then
		error(("[DataStoreStage.GetSubStore] - Already have a writer for %q"):format(name))
	end

	local newStore = DataStoreStage.new()
	self._takenKeys[name] = true
	self._maid:GiveTask(newStore)

	self._stores[name] = newStore

	return newStore
end

function DataStoreStage:StoreOnValueChange(name, valueObj)
	assert(type(name) == "string")
	assert(typeof(valueObj) == "Instance")

	if self._takenKeys[name] then
		error(("[DataStoreStage] - Already have a writer for %q"):format(name))
	end

	self._takenKeys[name] = true
	local conn = valueObj.Changed:Connect(function()
		self:_doStore(name, valueObj.Value)
	end)
	self._maid:GiveTask(conn)
	return conn
end

function DataStoreStage:HasWritableData()
	if self._dataToSave then
		return true
	end

	for _, value in pairs(self._stores) do
		if value:HasWritableData() then
			return true
		end
	end

	return false
end

--- Constructs a writer which provides a snapshot of the current data state to write
function DataStoreStage:GetNewWriter()
	local writer = DataStoreWriter.new()
	if self._dataToSave then
		writer:SetRawData(self._dataToSave)
	end

	for name, store in pairs(self._stores) do
		if store:HasWritableData() then
			writer:AddWriter(name, store:GetNewWriter())
		end
	end

	return writer
end

-- Stores the data for overwrite.
function DataStoreStage:_doStore(name, value)
	assert(type(name) == "string")
	assert(value ~= nil)

	local newValue
	if type(value) == "Table" then
		newValue = Table.DeepCopy(value)
	else
		newValue = value
	end

	if not self._dataToSave then
		self._dataToSave = {}
	end

	self._dataToSave[name] = newValue
end


return DataStoreStage