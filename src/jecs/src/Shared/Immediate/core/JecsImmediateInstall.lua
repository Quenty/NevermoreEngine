--!nonstrict
--[=[
	@class JecsImmediateInstall

	Factory: `JecsImmediateInstall(components?, DEBUG?)` returns an
	ImmediateInstall addon `(rt, scheduler) -> rt'`.

	This adds a JECS world to an immediate runtime.
	It's the basis for the hooks addon, and possibly some or all of your game state.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local ImmediateScheduler = require("ImmediateScheduler")
local Jecs = require("Jecs")
local JecsImmediateCoreComponents = require("JecsImmediateCoreComponents")
local JecsImmediateUtils = require("JecsImmediateUtils")
local Jecst = require("Jecst")

export type JecsAddon = {
	world: Jecst.World,
	comps: JecsImmediateUtils.JecsComponentDictionary,
	jecs: typeof(Jecs),
}
export type ImmediateRuntime_Jecs<Rt = {}> = Rt & ImmediateCoreUtils.ImmediateRuntime & JecsAddon

local function install<Rt>(
	rt: Rt,
	components: JecsImmediateUtils.JecsComponentDictionary?,
	DEBUG: boolean?
): ImmediateRuntime_Jecs<Rt>
	local runtime = rt :: Rt & ImmediateCoreUtils.ImmediateRuntime
	local world = Jecs.world(DEBUG)
	-- Jecs World has no Destroy; Maid.Add would warn and no-op on cleanup.
	runtime.maid:GiveTask(function()
		world:cleanup()
		table.clear(world)
	end)

	local comps = JecsImmediateCoreComponents(world)
	if components then
		for name, component in pairs(components) do
			comps[name] = component
		end
	end
	JecsImmediateUtils._setupComponentDictionaryWithWorld(world, comps)

	runtime.world = world
	runtime.comps = comps
	runtime.jecs = Jecs

	JecsImmediateUtils._setupRuntimeMaidComponentCallbacks(runtime)

	return runtime
end

-- Factory: close over components/DEBUG, return an ImmediateInstall addon.
return function(components: JecsImmediateUtils.JecsComponentDictionary?, DEBUG: boolean?)
	return function<Rt>(rt: Rt, _scheduler: ImmediateScheduler.ImmediateScheduler): ImmediateRuntime_Jecs<Rt>
		return install(rt, components, DEBUG)
	end
end
