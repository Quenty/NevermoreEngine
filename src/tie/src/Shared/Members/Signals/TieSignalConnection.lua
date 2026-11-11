--!strict
--[=[
	@class TieSignalConnection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local TieUtils = require("TieUtils")

local TieSignalConnection = {}
TieSignalConnection.ClassName = "TieSignalConnection"
TieSignalConnection.__index = TieSignalConnection

export type TieSignalConnection = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_connected: boolean,
		_tieSignalInterface: any,
		_callback: (...any) -> (),
	},
	{} :: typeof({ __index = TieSignalConnection })
))

function TieSignalConnection.new(tieSignalInterface: any, callback: (...any) -> ()): TieSignalConnection
	local self: TieSignalConnection = setmetatable({} :: any, TieSignalConnection)

	self._maid = Maid.new()
	self._connected = true

	self._tieSignalInterface = assert(tieSignalInterface, "No tieSignalInterface")
	self._callback = assert(callback, "No callback")

	self:_connect()

	return self
end

function TieSignalConnection.Disconnect(self: TieSignalConnection): ()
	self:Destroy()
end

function TieSignalConnection._connect(self: TieSignalConnection): ()
	self._maid:GiveTask(self._tieSignalInterface:ObserveBindableEventBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, bindableEvent = brio:ToMaidAndValue()
		maid:GiveTask(bindableEvent.Event:Connect(function(...)
			task.spawn(self._callback, TieUtils.decode(...))
		end))
	end))
end

local rawTieSignalConnection = TieSignalConnection :: any
rawTieSignalConnection.__index = function(self, index)
	if index == "_tieSignalInterface" then
		return rawget(self, index)
	elseif index == "IsConnected" then
		return self._connected
	elseif TieSignalConnection[index] then
		return TieSignalConnection[index]
	else
		error(string.format("Bad index %q for TieSignalConnection", tostring(index)))
	end
end

function TieSignalConnection.Destroy(self: TieSignalConnection): ()
	self._connected = false
	self._maid:DoCleaning()
	-- Avoid setting the metatable so calling methods is always valid
end

return TieSignalConnection
