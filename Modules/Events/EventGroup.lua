local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local lib = {}

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0));

-- EventBin.lua
-- A library to handle events. It is beautiful.

-- @author Anaminus, modified by Quenty
-- Last modified by Quenty, January 23rd, 2014

--[[-- Change Log --
January 23rd, 2014
- Updated to new class system

January 19th, 2014
- Modified to work with Module Scripts
- Added Change Log

--]]

--[[----------------------------------------------------------------------------
EventGroup
	Manages event connections. Added events will remain until removal. Removed events are automatically disconnected.
	Subgroups, which are EventGroups, can also be added.

	Adding an event*:
		EventGroup.EventName = (event)
	Removing (and disconnecting) an event:
		EventGroup.EventName = nil

	Adding a new subgroup (and adding event to that group)**:
		EventGroup.NewGroup.EventName = (event)
	Removing a subgroup (and removing all of the group's events):
		EventGroup.NewGroup = nil

	Getting all events:
		EventGroup("GetEvents")
	Getting all subgroups:
		EventGroup("GetGroups")
	Removing all events and subgroups:
		EventGroup("Clear")

	*If an event or group already exists with the same name, it will first be removed.
	**The group does not have to be created beforehand.
]]

local MakeEventGroup
MakeEventGroup = Class(function(def)
	local eventContainer = {}
	local groupContainer = {}

	local methods = {
		GetEvents = function(self)
			local copy = {}
			for name,event in pairs(eventContainer) do
				copy[name] = event
			end
			return copy
		end;
		GetGroups = function(self)
			local copy = {}
			for name,group in pairs(groupContainer) do
				copy[name] = group
			end
			return copy
		end;
		Clear = function(self)
			for k in pairs(eventContainer) do
				self[k] = nil
			end
			for k in pairs(groupContainer) do
				self[k] = nil
			end
		end;
	}

	setmetatable(def,{
		__index = function(t,k)
			local event = eventContainer[k]
			if event then
				return event
			else
				local group = groupContainer[k]
				if group == nil then
					group = MakeEventGroup()
					groupContainer[k] = group
				end
				return group
			end
		end;
		__newindex = function(t,k,v)
			local event = eventContainer[k]
			if event ~= nil then
				event:disconnect()
				eventContainer[k] = nil
			else
				local group = groupContainer[k]
				if group ~= nil then
					group("Clear")
					groupContainer[k] = nil
				end
			end
			if v ~= nil then
				eventContainer[k] = v
			end
		end;
		__call = function(self,name,...)
			if methods[name] then
				return methods[name](self,...)
			else
				error("EventGroup: "..tostring(name).." is not a valid method", 2)
			end
		end;
	})
end)
lib.MakeEventGroup = MakeEventGroup;
lib.makeEventGroup = MakeEventGroup;

return lib