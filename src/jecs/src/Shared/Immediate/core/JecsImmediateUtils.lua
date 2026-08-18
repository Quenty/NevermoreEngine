--!nonstrict

-- For specifically integrating with an ImmediateUtils Scheduler.
local require = require(script.Parent.loader).load(script)

local ImmediateCoreUtils = require("ImmediateCoreUtils")
local Jecs = require("Jecs")
local JecsImmediateCoreComponents = require("JecsImmediateCoreComponents")
local Jecst = require("Jecst")
local Maid = require("Maid")
local Observable = require("Observable")

local JecsImmediateUtils = {}

-- A component dictionary is a dictionary of component ids that also registers them to a JECS world (side effects).
export type JecsComponentDictionary = { [string]: Jecst.Id<any> } & typeof(JecsImmediateCoreComponents({} :: Jecst.World))

-- A component info table is a table (commonly returned by modules) containing a common function to apply and return a component dictionary.
-- You would make your own modules that expose this as a function, like SomeProjectHere._applyAndReturnComponentDictionary
-- Within it, you'd define what components (what data shapes) you'd like to use with jecs state.
-- The components would be registered as valid Jecs components during runtime,
-- but here we can also expose the returned components statically.
export type JecsComponentDictionaryInjector = (world: Jecst.World) -> JecsComponentDictionary

local function attachCallbackTables(
	world: Jecst.World,
	fullComponentDictionary: JecsComponentDictionary,
	component: Jecst.Id<any>
)
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

local function bindComponentLifecycle(
	world: Jecst.World,
	fullComponentDictionary: JecsComponentDictionary,
	component: Jecst.Id<any>
)
	world:set(component, Jecs.OnChange, function(entity, id, data)
		local changeCallbacks = world:get(id, fullComponentDictionary._ChangeCallbacks)
		if changeCallbacks then
			for _key, callback in pairs(changeCallbacks.callbacks) do
				callback(entity, id, data)
			end
		end
	end)
	world:set(component, Jecs.OnAdd, function(entity, id, data)
		local addCallbacks = world:get(id, fullComponentDictionary._AddCallbacks)
		if addCallbacks then
			for _key, callback in pairs(addCallbacks.callbacks) do
				callback(entity, id, data)
			end
		end
	end)
	world:set(component, Jecs.OnRemove, function(entity, id, delete)
		local removeCallbacks = world:get(id, fullComponentDictionary._RemoveCallbacks)
		if removeCallbacks then
			for _key, callback in pairs(removeCallbacks.callbacks) do
				callback(entity, id, delete)
			end
		end
	end)
end

-- Register extra components into an already-setup dictionary. Uses the core
-- Name / callback ids from `fullComponentDictionary`. Do not pass a fragment
-- into `_setupComponentDictionaryWithWorld` — that function assumes a complete dict.
function JecsImmediateUtils._registerComponentsWithWorld(
	world: Jecst.World,
	fullComponentDictionary: JecsComponentDictionary,
	newComponents: { [string]: Jecst.Id<any> }
)
	assert(fullComponentDictionary.Name, "JecsImmediateInstall must run first (missing comps.Name)")
	assert(fullComponentDictionary._ChangeCallbacks, "missing comps._ChangeCallbacks")

	for componentName, component in pairs(newComponents) do
		(fullComponentDictionary :: {})[componentName] = component
		attachCallbackTables(world, fullComponentDictionary, component)
		bindComponentLifecycle(world, fullComponentDictionary, component)
		world:set(component, fullComponentDictionary.Name, componentName)
	end
end

function JecsImmediateUtils._setupComponentDictionaryWithWorld(
	world: Jecst.World,
	fullComponentDictionary: JecsComponentDictionary
)
	for _componentName, component in pairs(fullComponentDictionary) do
		if
			component == fullComponentDictionary._ChangeCallbacks
			or component == fullComponentDictionary._AddCallbacks
			or component == fullComponentDictionary._RemoveCallbacks
		then
			continue
		end
		attachCallbackTables(world, fullComponentDictionary, component)
	end

	-- Every component will run callbacks assigned to them.
	for _componentName, component in pairs(fullComponentDictionary) do
		bindComponentLifecycle(world, fullComponentDictionary, component)
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

	-- Every component should have their Name component set.
	for _componentName, component in pairs(fullComponentDictionary) do
		world:set(component, fullComponentDictionary.Name, _componentName)
	end
end

function JecsImmediateUtils._setupRuntimeMaidComponentCallbacks(rt: ImmediateCoreUtils.ImmediateRuntime)
	local world = rt.world
	local maidComponent = assert(rt.comps.Maid, "no Maid component in runtime")

	local trackEntityMaid = function(entity, _, m)
		assert(Maid.isMaid(m), "Maid component must be a Maid")
		rt.maid[`{entity}_maid`] = m
	end
	JecsImmediateUtils.addAddCallback(rt, maidComponent, trackEntityMaid, "trackEntityMaid")
	JecsImmediateUtils.addChangeCallback(rt, maidComponent, trackEntityMaid, "trackEntityMaid")
	JecsImmediateUtils.addRemoveCallback(rt, maidComponent, function(entity)
		rt.maid[`{entity}_maid`] = nil
		local entityMaid = world:get(entity, maidComponent)
		if entityMaid then
			entityMaid:DoCleaning()
		end
	end, "maid")
end

function JecsImmediateUtils.childOf(r, et)
	return r.jecs.pair(r.jecs.ChildOf, et)
end

function JecsImmediateUtils.countQuery(query: Jecst.Query<any>): number
	local count = 0
	for _ in query do
		count += 1
	end
	return count
end

function JecsImmediateUtils.firstOfQuery(query: Jecst.Query<any>): Jecst.Entity?
	for entity in query do
		return entity
	end
	return nil
end

function JecsImmediateUtils.getMaid(r: ImmediateCoreUtils.ImmediateRuntime, entity: Jecst.Entity): Maid.Maid?
	return r.world:get(entity, r.comps.Maid)
end

function JecsImmediateUtils.getAMaid(r: ImmediateCoreUtils.ImmediateRuntime, entity: Jecst.Entity): Maid.Maid?
	local directMaid = r.world:get(entity, r.comps.Maid)
	if directMaid then
		return directMaid
	end
	while true do
		local parent = r.world:parent(entity)
		if not parent then
			break
		end
		entity = parent
		local parentMaid = r.world:get(parent, r.comps.Maid)
		if parentMaid then
			return parentMaid
		end
	end
	return r.maid
end

export type RxECSQueuedEmitIterator = ({ any }, number?) -> (number?, any?)

function JecsImmediateUtils.drainQueuedSnapshot(snapshot: { any }, index: number?): (number?, any?)
	local nextIndex = (index or 0) + 1
	local value = snapshot[nextIndex]
	if value == nil then
		return nil
	end
	return nextIndex, unpack(value)
end

export type RxECSObservableCollector = {
	Drain: () -> (RxECSQueuedEmitIterator, { any }, number),
	Last: () -> ...any,
	Destroy: () -> (),
}

function JecsImmediateUtils.collectObservable(
	observable: Observable.Observable<any>,
	maid: Maid.Maid?
): RxECSObservableCollector
	local queueOfEmits = {}
	local lastEmit = nil
	local collectorMaid = Maid.new()
	collectorMaid:GiveTask(observable:Subscribe(function(...)
		table.insert(queueOfEmits, table.pack(...))
		lastEmit = table.pack(...)
	end))
	collectorMaid:GiveTask(function()
		table.clear(queueOfEmits)
		lastEmit = nil
	end)
	if maid then
		maid:GiveTask(collectorMaid)
	end
	return {
		Drain = function()
			local snapshot = queueOfEmits
			queueOfEmits = {}
			return JecsImmediateUtils.drainQueuedSnapshot, snapshot, 0
		end,
		Last = function()
			if lastEmit == nil then
				return nil
			end
			return unpack(lastEmit)
		end,
		Destroy = function()
			collectorMaid:DoCleaning()
		end,
	}
end

-- loop for changed for a component, but use in a loop over many entities.
-- use like:
-- for entity, chrec in hooks.subscribe(observeComponentOnChanged(r, component)) do
-- and this would loop over all entities who got the component.
-- but only this component. use chrec.removed to see if it's actually removed or if the
-- component was simply a tag without data.
function JecsImmediateUtils.observeComponentOnChanged(
	r: ImmediateCoreUtils.ImmediateRuntime,
	component: Jecst.Id<any>
): Observable.Observable<
	Jecst.Entity,
	{ curr: any?, removed: boolean }
>
	assert(component, `Component not found`)
	return Observable.new(function(sub)
		local maid = Maid.new()
		maid:GiveTask(JecsImmediateUtils.addAddCallback(r, component, function(_entity, _id, data)
			sub:Fire(_entity, { curr = data, removed = false })
		end))
		maid:GiveTask(JecsImmediateUtils.addChangeCallback(r, component, function(_entity, _id, data)
			sub:Fire(_entity, { curr = data, removed = false })
		end))
		maid:GiveTask(JecsImmediateUtils.addRemoveCallback(r, component, function(_entity, _id, _data)
			sub:Fire(_entity, { curr = nil, removed = true })
		end))
		for entity, data in r.world:query(component) do
			sub:Fire(entity, { curr = data, removed = false })
		end
		return maid
	end)
end

function JecsImmediateUtils.observeComponentData(
	r: ImmediateCoreUtils.ImmediateRuntime,
	entity: Jecst.Entity,
	component: Jecst.Id<any>
): Observable.Observable<any>
	assert(entity, `Entity not found for component: {component}`)
	assert(component, `Component not found for entity: {entity}`)
	return Observable.new(function(sub)
		local maid = Maid.new()
		maid:GiveTask(JecsImmediateUtils.addAddCallback(r, component, function(_entity, _id, data)
			if _entity ~= entity then
				return
			end
			sub:Fire(data)
		end))
		maid:GiveTask(JecsImmediateUtils.addChangeCallback(r, component, function(_entity, _id, data)
			if _entity ~= entity then
				return
			end
			sub:Fire(data)
		end))
		local data = r.world:get(entity, component)
		if data then
			sub:Fire(data)
		end
		return maid
	end)
end

function JecsImmediateUtils.addChangeCallback(
	r: ImmediateCoreUtils.ImmediateRuntime,
	component: Jecst.Id<any>,
	callback: (entity: Jecst.Entity, id: number, data: any) -> (),
	key: any?
)
	local changeCallbacks = r.world:get(component, r.comps._ChangeCallbacks)
	assert(changeCallbacks, `Change callbacks not found for component: {component}`)
	assert(changeCallbacks.callbacks, `Change callbacks not found for component: {component}`)
	assert(changeCallbacks._counter, `Change callbacks counter not found for component: {component}`)

	if not key then
		key = changeCallbacks._counter
		changeCallbacks._counter += 1
	end
	changeCallbacks.callbacks[key] = callback

	return function()
		changeCallbacks.callbacks[key] = nil
	end
end

function JecsImmediateUtils.addAddCallback(
	r: ImmediateCoreUtils.ImmediateRuntime,
	component: Jecst.Id<any>,
	callback: (entity: Jecst.Entity, id: number, data: any) -> (),
	key: any?
)
	local addCallbacks = r.world:get(component, r.comps._AddCallbacks)
	assert(addCallbacks, `Add callbacks not found for component: {component}`)
	assert(addCallbacks.callbacks, `Add callbacks not found for component: {component}`)
	assert(addCallbacks._counter ~= nil, `Add callbacks counter not found for component: {component}`)

	if not key then
		key = addCallbacks._counter
		addCallbacks._counter += 1
	end
	addCallbacks.callbacks[key] = callback

	return function()
		addCallbacks.callbacks[key] = nil
	end
end

function JecsImmediateUtils.addRemoveCallback(
	r: ImmediateCoreUtils.ImmediateRuntime,
	component: Jecst.Id<any>,
	callback: (entity: Jecst.Entity, id: number, delete: boolean?) -> (),
	key: any?
)
	local removeCallbacks = r.world:get(component, r.comps._RemoveCallbacks)
	assert(removeCallbacks, `Remove callbacks not found for component: {component}`)
	assert(removeCallbacks.callbacks, `Remove callbacks not found for component: {component}`)
	assert(removeCallbacks._counter ~= nil, `Remove callbacks counter not found for component: {component}`)

	if not key then
		key = removeCallbacks._counter
		removeCallbacks._counter += 1
	end
	removeCallbacks.callbacks[key] = callback

	return function()
		removeCallbacks.callbacks[key] = nil
	end
end

function JecsImmediateUtils.patch(
	rt: ImmediateCoreUtils.ImmediateRuntime,
	et: Jecst.Entity,
	comp: Jecst.Id<any>,
	partialData: { any }
)
	local data = rt.world:get(et, comp)
	if not data then
		return
	end
	for key, value in partialData do
		data[key] = value
	end
	rt.world:set(et, comp, data)
end

return JecsImmediateUtils
