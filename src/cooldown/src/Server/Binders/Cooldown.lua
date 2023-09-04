--[=[
	Represents a cooldown state with a time limit. See [CooldownBase] for more API.

	@server
	@class Cooldown
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local TimeSyncService = require("TimeSyncService")
local CooldownConstants = require("CooldownConstants")
local AttributeValue = require("AttributeValue")
local Binder = require("Binder")
local PropertyValue = require("PropertyValue")

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

--[=[
	Constructs a new cooldown. Should be done via [Binder].

	@param numberValue NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function Cooldown.new(numberValue, serviceBag)
	local self = setmetatable(CooldownBase.new(numberValue, serviceBag), Cooldown)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._syncedClock = self._serviceBag:GetService(TimeSyncService):GetSyncedClock()

	self._finishTime = PropertyValue.new(self._obj, "Value")
	self._startTime = AttributeValue.new(self._obj, CooldownConstants.COOLDOWN_START_TIME_ATTRIBUTE, self._syncedClock:GetTime())

	self._maid:GiveTask(self.Done:Connect(function()
		self._obj:Remove()
	end))

	return self
end

return Binder.new("Cooldown", Cooldown)