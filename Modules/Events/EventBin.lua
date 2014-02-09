local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0))


-- EventBin.lua
-- A library to handle events
-- @author Anaminus, modified by Quenty
-- Last modified by Quenty, January 23rd, 2014

--[[-- Change Log --
February 3rd, 2014
- Fixed qSystem dependency

January 23rd, 2014
- Fixed bug with Nevermore being required
- Updated to new class system

January 19th, 2014
- Modified to work with Module Scripts
- Added Change Log

--]]

local lib = {}

local MakeEventBin = Class(function(this)
	--- Creates a bin that manages / stores events.

	local mEvents = {}
	function this:add(evt)
		mEvents[#mEvents+1] = evt
	end
	this.Add = this.add
	function this:clear()
		for _, evt in pairs(mEvents) do
			evt:disconnect()
		end
		mEvents = {}
	end
	this.Clear = this.clear
	function this:destroy()
		for _, evt in pairs(mEvents) do
			evt:disconnect()
		end

		for index, value in pairs(this) do
			this[index] = nil;
		end
	end
	this.Destroy = this.destroy
end)
lib.MakeEventBin = MakeEventBin
lib.makeEventBin = MakeEventBin

lib.new = MakeEventBin
lib.New = MakeEventBin

return lib