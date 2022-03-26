--[=[
	@class TieSignalConnection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TieUtils = require("TieUtils")

local TieSignalConnection = {}
TieSignalConnection.ClassName = "TieSignalConnection"
TieSignalConnection.__index = TieSignalConnection

function TieSignalConnection.new(memberDefinition, adornee, callback)
	local self = setmetatable({}, TieSignalConnection)

	self._maid = Maid.new()

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._adornee = assert(adornee, "No adornee")
	self._callback = assert(callback, "No callback")

	self._connected = true
	self._tieDefinition = self._memberDefinition:GetTieDefinition()

	self:_connect()

	return self
end

function TieSignalConnection:Disconnect()
	self:Destroy()
end

function TieSignalConnection:_connect()
	self._maid:GiveTask(self:_observeBindableEvent():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local bindableEvent = brio:GetValue()

		maid:GiveTask(bindableEvent.Event:Connect(function(...)
			task.spawn(self._callback, TieUtils.decode(...))
		end))
	end))
end

function TieSignalConnection:_observeFolderBrio()
	local containerName = self._tieDefinition:GetContainerName()

	return RxInstanceUtils.observeLastNamedChildBrio(self._adornee, "Folder", containerName)
end

function TieSignalConnection:_observeBindableEvent()
	local name = self._memberDefinition:GetMemberName()

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(folder)
			return RxInstanceUtils.observeLastNamedChildBrio(folder, "BindableEvent", name)
		end);
	})
end

function TieSignalConnection:__index(index)
	if index == "IsConnected" then
		return self._connected
	elseif TieSignalConnection[index] then
		return TieSignalConnection[index]
	else
		error(("Bad index %q for TieSignalConnection"):format(tostring(index)))
	end
end

function TieSignalConnection:Destroy()
	self._connected = false
	self._maid:DoCleaning()
	-- Avoid setting the metatable so calling methods is always valid
end

return TieSignalConnection