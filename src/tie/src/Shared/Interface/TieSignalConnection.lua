--[=[
	@class TieSignalConnection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local TieInterfaceUtils = require("TieInterfaceUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local TieUtils = require("TieUtils")

local TieSignalConnection = {}
TieSignalConnection.ClassName = "TieSignalConnection"
TieSignalConnection.__index = TieSignalConnection

function TieSignalConnection.new(memberDefinition, folder, adornee, callback)
	local self = setmetatable({}, TieSignalConnection)

	assert(folder or adornee, "Folder or adornee required")

	self._maid = Maid.new()

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._folder = folder
	self._adornee = adornee
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
	return TieInterfaceUtils.observeFolderBrio(self._tieDefinition, self._folder, self._adornee)
end

function TieSignalConnection:_observeBindableEvent()
	local name = self._memberDefinition:GetMemberName()

	return self:_observeFolderBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(folder)
			return RxInstanceUtils.observeLastNamedChildBrio(folder, "BindableEvent", name)
		end);
		RxBrioUtils.onlyLastBrioSurvives();
	})
end

function TieSignalConnection:__index(index)
	if index == "_adornee" or index == "_folder" then
		return rawget(self, index)
	elseif index == "IsConnected" then
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