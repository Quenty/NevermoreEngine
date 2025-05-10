--!strict
--[=[
	@class CooldownShared
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local CooldownBase = require("CooldownBase")
local ServiceBag = require("ServiceBag")

local CooldownShared = setmetatable({}, CooldownBase)
CooldownShared.ClassName = "CooldownShared"
CooldownShared.__index = CooldownShared

export type CooldownShared = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = CooldownShared })
)) & CooldownBase.CooldownBase

function CooldownShared.new(numberValue: NumberValue, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(CooldownBase.new(numberValue, serviceBag), CooldownShared)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("Cooldown", CooldownShared :: any) :: Binder.Binder<CooldownShared>
