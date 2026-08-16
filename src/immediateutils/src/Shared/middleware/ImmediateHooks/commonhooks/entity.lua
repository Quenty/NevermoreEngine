--!strict
--[=[
	@class entity

	Use this within a hook's discriminator argument, such as:
	`gatecounter(entity(SomeEntityHere))`.

	This tells getOrCreateHookState to parent the hook entity to SomeEntityHere.
	If the entity dies, the hook will be cleaned up.
]=]

local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecst = require("Jecst")

return function(_rt: ImmediateTypes.ImmediateRuntime)
	return function(entity: Jecst.Entity)
		return { __hookentity = entity }
	end
end
