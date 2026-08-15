--!nonstrict

-- These components are assumed to exist in any ImmediateRuntime world. (they're required.)
-- Component files like these should be factory functions because they have to directly apply and call stuff on the jecs world.
local require = require(script.Parent.loader).load(script)

local ImmediateCoreComponents = require("ImmediateCoreComponents")
local ImmediateTypes = require("ImmediateTypes")
local Jecs = require("Jecs")
local Jecst = require("Jecst")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local ImmediateCoreUtils = {}

-- This sets up some meta behavior, and should be called exactly once given a world and a full component dictionary.
local function _setupComponentDictionaryWithWorld(
	world: Jecst.World,
	fullComponentDictionary: ImmediateTypes.JecsComponentDictionary
)
	for _componentName, component in pairs(fullComponentDictionary) do
		if
			component == fullComponentDictionary._ChangeCallbacks
			or component == fullComponentDictionary._AddCallbacks
			or component == fullComponentDictionary._RemoveCallbacks
		then
			continue
		end
		world:set(component, fullComponentDictionary._ChangeCallbacks, {
			_counter = 0,
			callbacks = {},
		})
		world:set(component, fullComponentDictionary._AddCallbacks, {
			_counter = 0,
			callbacks = {},
		})
		world:set(component, fullComponentDictionary._RemoveCallbacks, {
			_counter = 0,
			callbacks = {},
		})
	end

	-- Every component will run callbacks assigned to them.
	for _componentName, component in pairs(fullComponentDictionary) do
		world:set(component, Jecs.OnChange, function(entity, id, data)
			local changeCallbacks = world:get(id, fullComponentDictionary._ChangeCallbacks)
			if changeCallbacks then
				for _key, callback in pairs(changeCallbacks.callbacks) do
					callback(entity, id, data)
				end
			end
		end)
	end

	for _componentName, component in pairs(fullComponentDictionary) do
		world:set(component, Jecs.OnAdd, function(entity, id, data)
			local addCallbacks = world:get(id, fullComponentDictionary._AddCallbacks)
			if addCallbacks then
				for _key, callback in pairs(addCallbacks.callbacks) do
					callback(entity, id, data)
				end
			end
		end)
	end

	for _componentName, component in pairs(fullComponentDictionary) do
		world:set(component, Jecs.OnRemove, function(entity, id, delete)
			local removeCallbacks = world:get(id, fullComponentDictionary._RemoveCallbacks)
			if removeCallbacks then
				for _key, callback in pairs(removeCallbacks.callbacks) do
					callback(entity, id, delete)
				end
			end
		end)
	end

	-- Cleanup behavior if for some reason we remove the _Callbacks themselves
	world:set(fullComponentDictionary._ChangeCallbacks, Jecs.OnRemove, function(entity)
		local changeCallbacks = world:get(entity, fullComponentDictionary._ChangeCallbacks)
		if changeCallbacks then
			table.clear(changeCallbacks.callbacks)
			table.clear(changeCallbacks)
		end
	end)

	world:set(fullComponentDictionary._AddCallbacks, Jecs.OnRemove, function(entity)
		local addCallbacks = world:get(entity, fullComponentDictionary._AddCallbacks)
		if addCallbacks then
			table.clear(addCallbacks.callbacks)
			table.clear(addCallbacks)
		end
	end)

	world:set(fullComponentDictionary._RemoveCallbacks, Jecs.OnRemove, function(entity)
		local removeCallbacks = world:get(entity, fullComponentDictionary._RemoveCallbacks)
		if removeCallbacks then
			table.clear(removeCallbacks.callbacks)
			table.clear(removeCallbacks)
		end
	end)

	-- Every component should usually have their Name component set.
	for _componentName, component in pairs(fullComponentDictionary) do
		world:set(component, fullComponentDictionary.Name, _componentName)
	end
end

local function _setupRuntimeMaidComponentCallbacks(rt: ImmediateTypes.ImmediateRuntime)
	local ImmediateJecsUtils = require("ImmediateJecsUtils")
	local world = rt.world
	local maidComponent = assert(rt.comps.Maid, "no Maid component in runtime")

	local trackEntityMaid = function(entity, _, m)
		assert(Maid.isMaid(m), "Maid component must be a Maid")
		rt.maid[`{entity}_maid`] = m
	end
	ImmediateJecsUtils.addAddCallback(rt, maidComponent, trackEntityMaid, "trackEntityMaid")
	ImmediateJecsUtils.addChangeCallback(rt, maidComponent, trackEntityMaid, "trackEntityMaid")
	ImmediateJecsUtils.addRemoveCallback(rt, maidComponent, function(entity)
		rt.maid[`{entity}_maid`] = nil
		local entityMaid = world:get(entity, maidComponent)
		if entityMaid then
			entityMaid:DoCleaning()
		end
	end, "maid")
end

function ImmediateCoreUtils.createImmediateRuntime<CustomComponentDictionaries, CustomBlackboardType>(
	serviceBag: ServiceBag.ServiceBag,
	requireCallback: (
		path: string
	) -> any,
	extraComponents: {
		[string]: Jecst.Id<any>,
	}?,
	debugEnabled: boolean?,
	plugin: Plugin?
): ImmediateTypes.ImmediateRuntime<
	CustomComponentDictionaries,
	CustomBlackboardType
>
	local maid = Maid.new()
	local DEBUG = debugEnabled ~= false
	local world = maid:Add(Jecs.world(DEBUG))
	local usingServiceBag = serviceBag or maid:Add(ServiceBag.new())

	-- Register initial components, exposing through rt.comps
	local comps = ImmediateCoreComponents(world)
	if extraComponents then
		for name, component in extraComponents do
			comps[name] = component
		end
	end
	_setupComponentDictionaryWithWorld(world, comps)

	-- Create final runtime table
	local runtime: ImmediateTypes.ImmediateRuntime<CustomComponentDictionaries, CustomBlackboardType>
	runtime = {
		DEBUG = DEBUG,
		require = requireCallback,
		serviceBag = usingServiceBag,

		jecs = Jecs,
		world = world,
		comps = comps,

		maid = maid,
		blackboard = {},

		errorlog = {
			lastErrorShout = 0,
		},

		Destroy = function()
			maid:DoCleaning()
			table.clear(runtime)
		end,

		plugin = plugin,
	} :: ImmediateTypes.ImmediateRuntime<CustomComponentDictionaries, CustomBlackboardType>

	_setupRuntimeMaidComponentCallbacks(runtime)

	return runtime
end

return ImmediateCoreUtils
