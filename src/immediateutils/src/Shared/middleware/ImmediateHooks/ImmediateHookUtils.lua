--!nonstrict
--[=[
	@class ImmediateHookUtils

	Optional runtime extension: hook entity lookup on `rt.hookBook`.
	Install onto a bare ImmediateRuntime before calling getOrCreateHookState.
]=]
local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecs = require("Jecs")
local Jecst = require("Jecst")
local Maid = require("Maid")

local WARN_HOOK_CLEANUP = false

export type HookBook = {
	orderOfCalls: { [string]: number },
	stateEntities: { [string]: { [any]: Jecst.Entity } },
}

export type ImmediateHookBookAddon = {
	hookBook: HookBook,
}

export type ImmediateRuntimeWithHookBook<C = {}, B = {}> = ImmediateTypes.ImmediateRuntime<C, B> & ImmediateHookBookAddon

local ImmediateHookUtils = {}

function ImmediateHookUtils.install<Rt>(rt: Rt): Rt & ImmediateHookBookAddon
	local runtime = rt :: Rt & ImmediateHookBookAddon
	if runtime.hookBook == nil then
		runtime.hookBook = {
			orderOfCalls = {},
			stateEntities = {},
		}
	end
	return runtime
end

local function getHookBook(rt: ImmediateRuntimeWithHookBook): HookBook
	return assert(rt.hookBook, "ImmediateHookUtils.install(rt) was not called")
end

function ImmediateHookUtils.getOrCreateHookState<T>(
	rt: ImmediateRuntimeWithHookBook,
	discriminator: any,
	cleanupIfTrue: ((state: T) -> boolean)?,
	runtimePersistent: boolean? -- be very careful using this. will not be cleaned up
): (T, Maid.Maid, Jecst.Entity)
	local hookBook = getHookBook(rt)
	local _filename = debug.info(3, "s")
	local _line = debug.info(3, "l")
	local _firstKey = `{_filename}:{_line}`

	-- Order of calls logged per file/line.
	-- If multiple hooks are called in the same line, we default to discriminating
	-- by the order of calls (so if you omitted the discriminator in a loop, you'd get a
	-- unique hook state per iteration).
	if not hookBook.orderOfCalls[_firstKey] then
		hookBook.orderOfCalls[_firstKey] = 0
	end
	hookBook.orderOfCalls[_firstKey] = hookBook.orderOfCalls[_firstKey] + 1

	local entityToParentTo = nil

	if
		discriminator
		and typeof(discriminator) == "number"
		and rt.world:contains(discriminator :: any)
		and discriminator > 50
	then
		warn(`Hook discriminator {discriminator} is an entity, did you mean to wrap it in hooks.entity()?`)
		warn(debug.traceback())
	end

	local _discriminator = discriminator
	if _discriminator and typeof(_discriminator) == "table" and _discriminator.__hookentity then
		entityToParentTo = _discriminator.__hookentity
		_discriminator = _discriminator.__hookentity
	end

	if _discriminator == nil then
		_discriminator = `__call_{hookBook.orderOfCalls[_firstKey]}`
	end

	if not hookBook.stateEntities[_firstKey] then
		hookBook.stateEntities[_firstKey] = {}
	end

	-- Find the hook state.
	local hookStateEntity = hookBook.stateEntities[_firstKey][_discriminator]
	if hookStateEntity then
		if not rt.world:contains(hookStateEntity) then
			hookBook.stateEntities[_firstKey][_discriminator] = nil
			hookBook.orderOfCalls[_firstKey] = nil
			error(`Hook state entity for {_filename}:{_line} with discriminator {_discriminator} is not in the world`)
		end
		local hookMaid = rt.world:get(hookStateEntity, rt.comps.Maid)
		local mhs = rt.world:get(hookStateEntity, rt.comps.MetaHookState)
		mhs.flagForCleanup = false
		return rt.world:get(hookStateEntity, rt.comps.HookState) :: T, hookMaid, hookStateEntity
	end

	-- If not, create it.
	local newHookEntity = rt.world:entity()
	if entityToParentTo then
		rt.world:add(newHookEntity, Jecs.pair(rt.comps.ChildOf, entityToParentTo))
	end
	if runtimePersistent then
		rt.world:add(newHookEntity, rt.comps.HookRuntimeBuffer)
	end
	local newHookState = {}
	local maid = Maid.new()

	-- The actual cleanup task should be defined in the returned maid.
	-- This one only clears the table.
	maid:GiveTask(function()
		hookBook.stateEntities[_firstKey][_discriminator] = nil
		hookBook.orderOfCalls[_firstKey] = nil
		if WARN_HOOK_CLEANUP then
			warn(`Cleaned up hook state for {_filename}:{_line} with discriminator {_discriminator}`)
		end
	end)
	rt.world:set(newHookEntity, rt.comps.MetaHookState, {
		filename = _filename,
		line = _line,
		discriminator = discriminator,
		flagForCleanup = false,
		shouldCleanupCallback = cleanupIfTrue,
		runtimePersistent = runtimePersistent,
	})
	rt.world:set(newHookEntity, rt.comps.Maid, maid)
	rt.world:set(newHookEntity, rt.comps.HookState, newHookState)
	hookBook.stateEntities[_firstKey][_discriminator] = newHookEntity

	return rt.world:get(newHookEntity, rt.comps.HookState) :: T, maid, newHookEntity
end

ImmediateHookUtils._getOrCreateHookState = ImmediateHookUtils.getOrCreateHookState

function ImmediateHookUtils.forceCleanupHooks(rt: ImmediateRuntimeWithHookBook)
	local toDelete = {}
	for entity, _mhs, _hs, _maid in rt.world:query(rt.comps.MetaHookState, rt.comps.HookState, rt.comps.Maid) do
		if _mhs.runtimePersistent then
			continue
		end
		table.insert(toDelete, entity)
	end
	for _, entity in toDelete do
		if rt.world:contains(entity) then
			rt.world:delete(entity)
		end
	end
end

function ImmediateHookUtils.forceCleanupHooksOfFile(rt: ImmediateRuntimeWithHookBook, filename: string)
	local toDelete = {}
	for entity, mhs in rt.world:query(rt.comps.MetaHookState) do
		if mhs.runtimePersistent then
			continue
		end
		if mhs.filename == filename then
			table.insert(toDelete, entity)
		else
			-- could be expanded full name, so split by '.' and get the last part.
			local lastPart = string.split(mhs.filename, ".")[#string.split(mhs.filename, ".")]
			if lastPart == filename then
				table.insert(toDelete, entity)
			end
		end
	end
	for _, entity in toDelete do
		if rt.world:contains(entity) then
			rt.world:delete(entity)
		end
	end
end

function ImmediateHookUtils.evaluateAndCleanupHooks(rt: ImmediateRuntimeWithHookBook)
	local toDelete = {}
	for entity, mhs, hs, _maid in rt.world:query(rt.comps.MetaHookState, rt.comps.HookState, rt.comps.Maid) do
		if mhs.runtimePersistent then
			continue
		end
		if not mhs.flagForCleanup then
			mhs.flagForCleanup = true
			continue
		end
		if mhs.shouldCleanupCallback == nil or mhs.shouldCleanupCallback(hs) then
			table.insert(toDelete, entity)
		end
	end
	for _, entity in toDelete do
		if rt.world:contains(entity) then
			rt.world:delete(entity)
		end
	end
	local orderOfCalls = getHookBook(rt).orderOfCalls
	for _key, _ in orderOfCalls do
		orderOfCalls[_key] = 0
	end
end

function ImmediateHookUtils.flushHookRuntimeBuffers(rt: ImmediateRuntimeWithHookBook)
	for _et, hookState, _ in rt.world:query(rt.comps.HookState, rt.comps.HookRuntimeBuffer) do
		if hookState.calledThisFrame then
			table.clear(hookState.tab)
		end
		hookState.calledThisFrame = false
	end
end

return ImmediateHookUtils
