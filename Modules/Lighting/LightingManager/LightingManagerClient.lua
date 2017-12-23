--- Stack-based lighting manager which puts server lighting at the bottom and then
-- allows properties to filter down based upon the stack. Handles lighting effects inside of lighting too.

local Lighting = game:GetService("Lighting")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local LightingManager = require("LightingManager")
local Table = require("Table")

local LightingManagerClient = setmetatable({}, LightingManager)
LightingManagerClient.__index = LightingManagerClient
LightingManagerClient.ClassName = "LightingManagerClient"

function LightingManagerClient.new()
	local self = setmetatable(LightingManager.new(), LightingManagerClient)
	
	self.Stack = {}
	
	return self
end

function LightingManagerClient:WithRemoteEvent(RemoteEvent)
	assert(not self.RemoteEvent)
	
	self.RemoteEvent = RemoteEvent or error("No RemoteEvent")
	
	local ServerData = {
		PropertyTable = {};
		Name = "ServerData";
	}
	table.insert(self.Stack, 1, ServerData)
	
	self.RemoteEvent.OnClientEvent:Connect(function(PropertyTable, Time)
		assert(type(PropertyTable) == "table")
		assert(type(Time) == "number")

		ServerData.PropertyTable = PropertyTable
	
		self:Update(Time)
	end)

	return self
end

function LightingManagerClient:Update(Time)
	Time = Time or 0
	
	local PropertyTable = self:GetPropertyTable(self.CachedCurrentTargets)
	local DeltaTable, CurrentValues = self:GetDesiredTweens(PropertyTable, self.CachedCurrentTargets)
	self.CachedCurrentTargets = CurrentValues
	
	self:TweenOnItem(Lighting, DeltaTable, Time)
	
	if #self.Stack >= 4 then
		warn("[LightingManagerClient] - Stack is sized greater than 4, may want to remove!")
	end
end

function LightingManagerClient:GetDesiredTweens(PropertyTable, CachedCurrentTargets)
	local DeltaTable = {}
	
	local function Recurse(DeltaTable, CurrentValueTable, ItemToCopy)
		for Property, Value in pairs(ItemToCopy) do
			if type(Value) == "table" then
				DeltaTable[Property] = DeltaTable[Property] or {}
				CurrentValueTable[Property] = CurrentValueTable[Property] or {}
				
				Recurse(DeltaTable[Property], CurrentValueTable[Property], Value)
			else
				if CurrentValueTable[Property] ~= Value then
					DeltaTable[Property] = Value
					CurrentValueTable[Property] = Value
				end
			end
		end
	end
	
	local CurrentValues = Table.DeepCopy(CachedCurrentTargets or {})
	Recurse(DeltaTable, CurrentValues, PropertyTable)
	
	return DeltaTable, CurrentValues
end

function LightingManagerClient:GetPropertyTable()
	-- Not that fast, that's for sure...
		
	local function Recurse(PropertyTable, ItemToCopy)		
		for Property, Value in pairs(ItemToCopy) do
			if type(Value) == "table" then
				PropertyTable[Property] = PropertyTable[Property] or {}
				
				assert(type(PropertyTable[Property]) == "table")
				
				Recurse(PropertyTable[Property], Value)
			else
				if PropertyTable[Property] == nil then
					--print("Comparing", Property, CurrentTargets[Property], Value)
					PropertyTable[Property] = Value
				end
			end
		end
	end
	
	local PropertyTable = {}

	for i=#self.Stack, 1, -1 do
		local Data = self.Stack[i]
		if Data.PropertyTable then
			Recurse(PropertyTable, Data.PropertyTable)
		else
			error("[LightingManagerClient] - Bad item on stack! No property data!")
		end
	end
	
	return PropertyTable
end

function LightingManagerClient:AddTween(Name, PropertyTable, Time)
	assert(type(PropertyTable) == "table")
	
	self:RemoveTween(Name, nil, true)
	
	table.insert(self.Stack, {
		Name = Name;
		PropertyTable = PropertyTable;
	})
	
	self:Update(Time)
	
	return function()
		self:RemoveTween(Name, Time)
	end
end

function LightingManagerClient:RemoveTween(Name, Time, DoNotUpdate)
	local Index = self:GetTweenIndex(Name)
	if Index then
		table.remove(self.Stack, Index)
		
		if not DoNotUpdate then
			self:Update(Time)
		end
		
		return true
	end
	
	return false
end

function LightingManagerClient:GetTweenIndex(Name)
	assert(type(Name) == "string")
	
	for Index, Item in pairs(self.Stack) do
		if Item.Name == Name then
			return Index
		end
	end
	
	return nil
end

return LightingManagerClient