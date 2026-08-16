--!nonstrict

-- These components are assumed to exist in any ImmediateRuntime world. (they're required.)
-- Component files like these should be factory functions because they have to directly apply and call stuff on the jecs world.

local require = require(script.Parent.loader).load(script)

local Jecs = require("Jecs")
local Jecst = require("Jecst")
local Maid = require("Maid")

return function(world: Jecst.World)
	local newComponents = {
		Name = Jecs.Name,
		Previous = Jecs.Rest,
		ChildOf = Jecs.ChildOf,

		Maid = world:component() :: Jecst.Id<Maid.Maid>,
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
		_ChangeCallbacks = world:component() :: Jecst.Id<{
			_counter: number,
			callbacks: { [string]: (entity: Jecst.Entity, id: number, data: any) -> () },
		}>,
		_AddCallbacks = world:component() :: Jecst.Id<{
			_counter: number,
			callbacks: { [string]: (entity: Jecst.Entity, id: number, data: any) -> () },
		}>,
		_RemoveCallbacks = world:component() :: Jecst.Id<{
			_counter: number,
			callbacks: { [string]: (entity: Jecst.Entity, id: number, delete: boolean?) -> () },
		}>,
	}
	return newComponents
end
