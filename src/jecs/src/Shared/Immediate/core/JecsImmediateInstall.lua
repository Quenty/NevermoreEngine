--!nonstrict
--[=[
	@class JecsImmediateInstall

	This adds a JECS world to an immediate runtime.
	It's the basis for the hooks addon, and possibly some or all of your game state.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateCoreUtils = require("ImmediateCoreUtils")
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

return function<Rt>(
	rt: Rt,
	components: JecsImmediateUtils.JecsComponentDictionary,
	DEBUG: boolean? -- scheduler: ImmediateScheduler.ImmediateScheduler?
): ImmediateRuntime_Jecs<Rt>
	local runtime = rt :: Rt & ImmediateCoreUtils.ImmediateRuntime
	local world = Jecs.world(DEBUG)
	-- Jecs World has no Destroy; Maid.Add would warn and no-op on cleanup.
	runtime.maid:GiveTask(function()
		world:cleanup()
		table.clear(world)
	end)

	-- Register initial components, exposing through rt.comps
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
