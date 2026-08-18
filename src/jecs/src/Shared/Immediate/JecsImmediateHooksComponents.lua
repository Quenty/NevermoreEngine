--!nonstrict

-- These components are assumed to exist in any ImmediateRuntime world. (they're required.)
-- Component files like these should be factory functions because they have to directly apply and call stuff on the jecs world.

local require = require(script.Parent.loader).load(script)

local Jecst = require("Jecst")

return function(world: Jecst.World)
	local newComponents = {
		MetaHookState = world:component() :: Jecst.Id<{
			filename: string,
			line: number,
			discriminator: any,
			flagForCleanup: boolean,
			shouldCleanupCallback: ((state: any) -> boolean)?,
			runtimePersistent: boolean?,
		}>,
		HookState = world:component() :: Jecst.Id<{ [any]: any }>,
		HookRuntimeBuffer = world:component() :: Jecst.Id<nil>,
	}
	return newComponents
end
