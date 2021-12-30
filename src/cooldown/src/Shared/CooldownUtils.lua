--[=[
	Helper methods for cooldown
	@class CooldownUtils
]=]

local require = require(script.Parent.loader).load(script)

local CooldownConstants = require("CooldownConstants")

local CooldownUtils = {}

function CooldownUtils.findCooldown(cooldownBinder, parent)
	assert(cooldownBinder, "Bad cooldownBinder")
	assert(typeof(parent) == "Instance", "Bad parent")

	local cooldownObj = parent:FindFirstChild(CooldownConstants.COOLDOWN_NAME)
	if not cooldownObj then
		return nil
	end

	return cooldownBinder:Get(cooldownObj)
end

function CooldownUtils.create(cooldownBinder, parent, length)
	assert(cooldownBinder, "Bad cooldownBinder")
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(length) == "number", "Bad length")
	assert(length > 0, "Bad length")

	local cooldown = Instance.new("NumberValue")
	cooldown.Value = length
	cooldown.Name = CooldownConstants.COOLDOWN_NAME
	cooldown.Parent = parent

	cooldownBinder:Bind(cooldown)

	return cooldown
end

return CooldownUtils