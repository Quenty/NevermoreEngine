--!strict
--[=[
	Represents a cooldown state with a time limit. See [CooldownBase] for more API.

	@server
	@class Cooldown
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local Binder = require("Binder")
local CooldownBase = require("CooldownBase")
local CooldownConstants = require("CooldownConstants")
local PropertyValue = require("PropertyValue")
local ServiceBag = require("ServiceBag")
local TimeSyncService = require("TimeSyncService")

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_syncedClock: TimeSyncService.SyncedClock,
		_finishTime: PropertyValue.PropertyValue<number>,
		_startTime: AttributeValue.AttributeValue<number>,
	},
	{} :: typeof({ __index = Cooldown })
)) & CooldownBase.CooldownBase

--[=[
	Constructs a new cooldown. Should be done via [Binder].

	@param numberValue NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function Cooldown.new(numberValue: NumberValue, serviceBag: ServiceBag.ServiceBag): Cooldown
	local self: Cooldown = setmetatable(CooldownBase.new(numberValue, serviceBag) :: any, Cooldown)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._timeSyncService = self._serviceBag:GetService(TimeSyncService) :: any
	self._syncedClock = assert(self._timeSyncService:GetSyncedClock(), "No synced clock")

	self._finishTime = PropertyValue.new(self._obj, "Value")
	self._startTime =
		AttributeValue.new(self._obj, CooldownConstants.COOLDOWN_START_TIME_ATTRIBUTE, self._syncedClock:GetTime())

	self._maid:GiveTask(self.Done:Connect(function()
		(self._obj :: any):Remove()
	end))

	return self
end

return Binder.new("Cooldown", Cooldown :: any) :: Binder.Binder<Cooldown>
