--!strict
--[=[
	@class ImmediateSystem
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateCoreComponents = require("ImmediateCoreComponents")
local Jecst = require("Jecst")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local ImmediateTypes = {}

-- A component dictionary is a dictionary of component ids; however, their definition requires side effects to be applied to the world.
-- The side effect is registering themselves to the world with their type.
-- Because of their side effects, these are usually returned by the _applyAndReturnComponentDictionary function of a component info table.
export type JecsComponentDictionary = { [string]: Jecst.Id<any> } & typeof(ImmediateCoreComponents({} :: Jecst.World))

-- A component info table is a table (commonly returned by modules) containing a common function to apply and return a component dictionary.
-- You would make your own modules that expose this as a function, like SomeProjectHere._applyAndReturnComponentDictionary
-- Within it, you'd define what components (what data shapes) you'd like to use with jecs state.
-- The components would be registered as valid Jecs components during runtime,
-- but here we can also expose the returned components statically.
export type JecsComponentDictionaryInjector = (world: Jecst.World) -> JecsComponentDictionary

-- An ImmediateRuntime is centered around one Jecst world.
-- It can be made synchronously/immediately.
-- This is the core that *all* ImmediateRuntimes must have, and only that much.
-- Your specific game or plugin can define its own "runtime-type", adding more fields onto this runtime
-- table if necessary.
export type ImmediateRuntime<CustomComponentDictionaries = {}, CustomBlackboardType = {}> = {
	-- A flag to enable debug mode, where you can run slower but correct checks.
	DEBUG: boolean,

	-- The backbone of any immediate runtime. (Thanks jecs!)
	jecs: Jecst.jecs,
	world: Jecst.World,
	comps: JecsComponentDictionary & CustomComponentDictionaries,

	-- A single maid that cleans up the entire runtime.
	maid: Maid.Maid,

	-- In case this is running inside a plugin.
	plugin: Plugin?,

	-- Nevermore/Raven portal.
	serviceBag: ServiceBag.ServiceBag,

	-- A raw require portal sometimes necessary for hooks that rely on the same require().
	-- (to escape complications with hot reloading)
	require: (path: string) -> any,

	-- The blackboard can be used to store any kind of state for all systems.
	-- Here, you won't have to worry about key-collision with the runtime table's root level.
	-- This is *only* CustomBlackboardType: `{ [any]: any } & B` makes Luau drop B's keys
	-- (every lookup is already `any`), so `localPlayer` would not show up.
	blackboard: CustomBlackboardType,

	errorlog: {
		lastErrorShout: number,
	},

	-- Scheduler cursors (set while a system/middleware runs; cleared after the frame).
	-- Gameplay-only neighbors (middleware skipped):
	previousSystem: any?,
	-- nextSystem: any?,

	-- Immediately adjacent invocations in the full schedule (includes middleware):
	previousRawSystem: any?,
	-- nextRawSystem: any?,

	-- clean up (maids can thus add this runtime table, and cleanup the entire runtime)
	Destroy: () -> (),

	-- allow new fields for hook addons to live in
	[any]: any,
}

return ImmediateTypes
