--!strict
--[=[
	Helper methods for cooldown. See [RxCooldownUtils] for [Rx] utilities.
	@class CooldownUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local BinderUtils = require("BinderUtils")

local CooldownUtils = {}

--[=[
	Creates a new Roblox instance representing a cooldown.
	@param parent Instance
	@param length number
	@return Instance
]=]
function CooldownUtils.create(parent: Instance, length: number): NumberValue
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(length) == "number", "Bad length")
	assert(length > 0, "Bad length")

	local cooldown = Instance.new("NumberValue")
	cooldown.Value = length
	cooldown.Name = "Cooldown"

	CollectionService:AddTag(cooldown, "Cooldown")

	cooldown.Parent = parent

	return cooldown
end

--[=[
	Finds a cooldown in a parent.
	@param cooldownBinder Binder<Cooldown | CooldownClient>
	@param parent Instance
	@return Cooldown? | CooldownClient?
]=]
function CooldownUtils.findCooldown(cooldownBinder, parent: Instance)
	assert(cooldownBinder, "Bad cooldownBinder")
	assert(typeof(parent) == "Instance", "Bad parent")

	return BinderUtils.findFirstChild(cooldownBinder, parent)
end

--[=[
	Makes a copy of the cooldown
	@param cooldown Instance
	@return Instance
]=]
function CooldownUtils.clone(cooldown: NumberValue): NumberValue
	assert(typeof(cooldown) == "Instance", "Bad cooldown")

	local copy = cooldown:Clone()

	return copy
end

return CooldownUtils
