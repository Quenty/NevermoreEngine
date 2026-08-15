--!nonstrict
local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecst = require("Jecst")
local Maid = require("Maid")
local Observable = require("Observable")

local ImmediateJecsUtils = {}

function ImmediateJecsUtils.childOf(r, et)
	return r.jecs.pair(r.jecs.ChildOf, et)
end

function ImmediateJecsUtils.countQuery(query: Jecst.Query<any>): number
	local count = 0
	for _ in query do
		count += 1
	end
	return count
end

function ImmediateJecsUtils.firstOfQuery(query: Jecst.Query<any>): Jecst.Entity?
	for entity in query do
		return entity
	end
	return nil
end

function ImmediateJecsUtils.getMaid(r: ImmediateTypes.ImmediateRuntime, entity: Jecst.Entity): Maid.Maid?
	return r.world:get(entity, r.comps.Maid)
end

function ImmediateJecsUtils.getAMaid(r: ImmediateTypes.ImmediateRuntime, entity: Jecst.Entity): Maid.Maid?
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

function ImmediateJecsUtils.drainQueuedSnapshot(snapshot: { any }, index: number?): (number?, any?)
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

function ImmediateJecsUtils.collectObservable(
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
			return ImmediateJecsUtils.drainQueuedSnapshot, snapshot, 0
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
function ImmediateJecsUtils.observeComponentOnChanged(
	r: ImmediateTypes.ImmediateRuntime,
	component: Jecst.Id<any>
): Observable.Observable<
	Jecst.Entity,
	{ curr: any?, removed: boolean }
>
	assert(component, `Component not found`)
	return Observable.new(function(sub)
		local maid = Maid.new()
		maid:GiveTask(ImmediateJecsUtils.addAddCallback(r, component, function(_entity, _id, data)
			sub:Fire(_entity, { curr = data, removed = false })
		end))
		maid:GiveTask(ImmediateJecsUtils.addChangeCallback(r, component, function(_entity, _id, data)
			sub:Fire(_entity, { curr = data, removed = false })
		end))
		maid:GiveTask(ImmediateJecsUtils.addRemoveCallback(r, component, function(_entity, _id, _data)
			sub:Fire(_entity, { curr = nil, removed = true })
		end))
		for entity, data in r.world:query(component) do
			sub:Fire(entity, { curr = data, removed = false })
		end
		return maid
	end)
end

function ImmediateJecsUtils.observeComponentData(
	r: ImmediateTypes.ImmediateRuntime,
	entity: Jecst.Entity,
	component: Jecst.Id<any>
): Observable.Observable<any>
	assert(entity, `Entity not found for component: {component}`)
	assert(component, `Component not found for entity: {entity}`)
	return Observable.new(function(sub)
		local maid = Maid.new()
		maid:GiveTask(ImmediateJecsUtils.addAddCallback(r, component, function(_entity, _id, data)
			if _entity ~= entity then
				return
			end
			sub:Fire(data)
		end))
		maid:GiveTask(ImmediateJecsUtils.addChangeCallback(r, component, function(_entity, _id, data)
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

function ImmediateJecsUtils.addChangeCallback(
	r: ImmediateTypes.ImmediateRuntime,
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

function ImmediateJecsUtils.addAddCallback(
	r: ImmediateTypes.ImmediateRuntime,
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

function ImmediateJecsUtils.addRemoveCallback(
	r: ImmediateTypes.ImmediateRuntime,
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

function ImmediateJecsUtils.patch(
	rt: ImmediateTypes.ImmediateRuntime,
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

return ImmediateJecsUtils
