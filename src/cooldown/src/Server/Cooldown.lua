--[=[
	Represents a cooldown state with a time limit. See [CooldownBase] for more API.

	@server
	@class Cooldown
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local TimeSyncService = require("TimeSyncService")
local CooldownConstants = require("CooldownConstants")
local AttributeUtils = require("AttributeUtils")

local Cooldown = setmetatable({}, CooldownBase)
Cooldown.ClassName = "Cooldown"
Cooldown.__index = Cooldown

--[=[
	Constructs a new cooldown. Should be done via [CooldownBindersServer]. To create an
	instance of this in Roblox, see [CooldownUtils.create].

	@param obj NumberValue
	@param serviceBag ServiceBag
	@return Cooldown
]=]
function Cooldown.new(obj, serviceBag)
	local self = setmetatable(CooldownBase.new(obj, serviceBag), Cooldown)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	local now = self._serviceBag:GetService(TimeSyncService):GetSyncedClock():GetTime()
	local startTime = AttributeUtils.initAttribute(self._obj, CooldownConstants.COOLDOWN_START_TIME_ATTRIBUTE, now)

	-- Delay for cooldown time
	-- TODO: Handle start tme changing
	task.delay(self._obj.Value + startTime - now, function()
		if self.Destroy then
			self._obj:Destroy()
		end
	end)

	return self
end

return Cooldown