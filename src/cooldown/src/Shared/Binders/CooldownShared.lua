--[=[
	@class CooldownShared
]=]

local require = require(script.Parent.loader).load(script)

local CooldownBase = require("CooldownBase")
local Binder = require("Binder")

local CooldownShared = setmetatable({}, CooldownBase)
CooldownShared.ClassName = "CooldownShared"
CooldownShared.__index = CooldownShared

function CooldownShared.new(numberValue, serviceBag)
	local self = setmetatable(CooldownBase.new(numberValue, serviceBag), CooldownShared)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("Cooldown", CooldownShared)