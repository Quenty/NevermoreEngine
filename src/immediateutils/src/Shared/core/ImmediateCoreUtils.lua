--!nonstrict

--[[

	An immediate runtime is state. It starts off as a table with the bare essentials,
	but can be extended with addons.

]]
local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local ImmediateCoreUtils = {}

-- This is the core that *all* ImmediateRuntimes must have, and only that much.
-- Your specific game or plugin can define its own "runtime-type", adding more
-- fields onto this runtime table if necessary.
-- Additional functionality can be installed if a package has an installer function
-- that takes in a runtime table and returns a modified runtime table.
export type ImmediateRuntime<CustomBlackboardType = {}> = {
	-- A flag to enable debug mode, where you can run slower but correct checks.
	DEBUG: boolean,

	-- A single maid that cleans up the entire runtime.
	maid: Maid.Maid,

	-- In case this is running inside a plugin.
	plugin: Plugin?,

	-- Nevermore/Raven portal.
	serviceBag: ServiceBag.ServiceBag,

	-- A raw require portal sometimes necessary for hooks that rely on the same require().
	-- (to escape complications with hot reloading)
	require: (path: string) -> any,

	-- The blackboard can be used to store any kind of state for all gameplay systems, defined
	-- manually. Addons won't touch this table; they'll use the top level runtime table (carefully.)
	-- Here, gameplay code won't have key-collisions with whatever addons are installed.
	blackboard: CustomBlackboardType,

	-- Errors inside immediate runtimes should not spam the output with the same errors,
	-- so error reporting is throttled.
	errorlog: {
		lastErrorShout: number,
	},

	-- Scheduler cursors (set while a system/middleware runs; cleared after the frame).
	-- Gameplay-only neighbors (middleware skipped):
	previousSystem: any?,

	-- Immediately adjacent invocations in the full schedule (includes any kind of added middleware):
	previousRawSystem: any?,

	-- clean up (maids can thus add this runtime table, and cleanup the entire runtime)
	Destroy: () -> (),

	-- allow new fields for hook addons to live in
	[any]: any,
}

function ImmediateCoreUtils.createImmediateRuntime<CustomBlackboardType>(
	serviceBag: ServiceBag.ServiceBag,
	requireCallback: (path: string) -> any,
	initialBlackboard: CustomBlackboardType?,
	plugin: Plugin?
): ImmediateRuntime
	local maid = Maid.new()
	local usingServiceBag = serviceBag or maid:Add(ServiceBag.new())

	-- Create final runtime table
	local runtime: ImmediateRuntime
	runtime = {
		require = requireCallback,
		serviceBag = usingServiceBag,
		maid = maid,
		blackboard = (initialBlackboard :: any) or {},

		errorlog = {
			lastErrorShout = 0,
		},

		Destroy = function()
			maid:DoCleaning()
			table.clear(runtime)
		end,

		plugin = plugin,
	} :: ImmediateRuntime

	return runtime
end

return ImmediateCoreUtils
