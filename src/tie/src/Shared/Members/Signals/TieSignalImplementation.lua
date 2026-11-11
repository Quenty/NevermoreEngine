--!strict
--[=[
	@class TieSignalImplementation
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local TieUtils = require("TieUtils")
local Tuple = require("Tuple")

local TieSignalImplementation = setmetatable({}, BaseObject)
TieSignalImplementation.ClassName = "TieSignalImplementation"
TieSignalImplementation.__index = TieSignalImplementation

export type TieSignalImplementation =
	typeof(setmetatable(
		{} :: {
			_memberDefinition: any,
			_implParent: Instance,
			_bindableEvent: BindableEvent,
		},
		{} :: typeof({ __index = TieSignalImplementation })
	))
	& BaseObject.BaseObject

function TieSignalImplementation.new(
	memberDefinition: any,
	implParent: Instance,
	initialValue: any
): TieSignalImplementation
	local self: TieSignalImplementation = setmetatable(BaseObject.new() :: any, TieSignalImplementation)

	self._memberDefinition = assert(memberDefinition, "No memberDefinition")
	self._implParent = assert(implParent, "No implParent")

	self._bindableEvent = self._maid:Add(Instance.new("BindableEvent"))
	self._bindableEvent.Archivable = false
	self._bindableEvent.Name = memberDefinition:GetMemberName()
	self._bindableEvent.Parent = self._implParent

	self:SetImplementation(initialValue)

	-- Since "actualSelf" can be quite large, we clean up our stuff aggressively for GC.
	self._maid:GiveTask(function()
		self._maid:DoCleaning()

		for key, _ in pairs(self :: any) do
			rawset(self :: any, key, nil)
		end
	end)

	return self
end

function TieSignalImplementation.SetImplementation(self: TieSignalImplementation, signal: any): ()
	local maid = Maid.new()

	if type(signal) == "table" then
		-- Prevent re-entrance from stuff fired from ourselves when forwarding events in either direction
		local signalFiredArgs = {}
		local bindableEventFiredArgs = {}

		maid:GiveTask(signal:Connect(function(...)
			local args = Tuple.new(...) :: any
			for pendingArgs, _ in signalFiredArgs do
				if pendingArgs == args then
					-- Remove from queue
					signalFiredArgs[pendingArgs] = nil
					return
				end
			end

			bindableEventFiredArgs[args] = true
			self._bindableEvent:Fire(TieUtils.encode(...))
		end))

		maid:GiveTask(self._bindableEvent.Event:Connect(function(...)
			local args = Tuple.new(TieUtils.decode(...)) :: any
			for pendingArgs, _ in bindableEventFiredArgs do
				if pendingArgs == args then
					-- Remove from queue
					bindableEventFiredArgs[pendingArgs] = nil
					return
				end
			end

			signalFiredArgs[args] = true
			signal:Fire(args:Unpack())
		end))
	end

	(self :: any)._maid._implementationMaid = maid
end

return TieSignalImplementation
