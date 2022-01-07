--[=[
	Helper methods for cooldown. See [RxCooldownUtils] for [Rx] utilities.
	@class CooldownUtils
]=]

local require = require(script.Parent.loader).load(script)

local BinderUtils = require("BinderUtils")

local CooldownUtils = {}

--[=[
	Creates a new Roblox instance representing a cooldown.
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@param length number
	@return Instance
]=]
function CooldownUtils.create(cooldownBinder, parent, length)
	assert(cooldownBinder, "Bad cooldownBinder")
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(length) == "number", "Bad length")
	assert(length > 0, "Bad length")

	local cooldown = Instance.new("NumberValue")
	cooldown.Value = length
	cooldown.Name = "Cooldown"

	cooldownBinder:Bind(cooldown)

	cooldown.Parent = parent

	return cooldown
end

--[=[
	Finds a cooldown in a parent.
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@return Cooldown? | CooldownClient?
]=]
function CooldownUtils.findCooldown(cooldownBinder, parent)
	assert(cooldownBinder, "Bad cooldownBinder")
	assert(typeof(parent) == "Instance", "Bad parent")

	return BinderUtils.findFirstChild(cooldownBinder, parent)
end


--[=[
	Makes a copy of the cooldown
	@param cooldown Instance
	@return Instance
]=]
function CooldownUtils.clone(cooldown)
	assert(typeof(cooldown) == "Instance", "Bad cooldown")

	local copy = cooldown:Clone()

	return copy
end

return CooldownUtils