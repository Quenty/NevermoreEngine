--!nonstrict
--[=[
	@class JecsImmediateHookUtils

	Hook entity lookup on `rt.hookBook`. ImmediateHooksInstall attaches the book
	to the runtime.
]=]
local require = require(script.Parent.loader).load(script)

local Jecs = require("Jecs")
local JecsImmediateInstall = require("JecsImmediateInstall")
local Jecst = require("Jecst")
local Maid = require("Maid")

local WARN_HOOK_CLEANUP = false

local JecsImmediateHookUtils = {}

export type HookBook = {
	orderOfCalls: { [string]: number },
	stateEntities: { [string]: { [any]: Jecst.Entity } },
}

export type ImmediateJecsHookBookAddon = {
	_hookBook: HookBook,
}

-- Hook infrastructure only. `rt.hooks` is introduced later by
-- JecsImmediateHooksCommonHooksInstall — Luau cannot overlay a nested field.
export type ImmediateRuntime_Jecs_HookBook<Rt = {}> =
	Rt
	& JecsImmediateInstall.ImmediateRuntime_Jecs<Rt>
	& ImmediateJecsHookBookAddon

export type ImmediateRuntime_Jecs_Hooks<Rt = {}> = ImmediateRuntime_Jecs_HookBook<Rt>

local function getHookBook(rt: ImmediateRuntime_Jecs_Hooks): HookBook
	return assert(rt._hookBook, "ImmediateHooksInstall was not applied")
end

function JecsImmediateHookUtils.getOrCreateHookState<T>(
	rt: ImmediateRuntime_Jecs_Hooks,
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

export type AverageableValue = number | Vector3 | Vector2

function JecsImmediateHookUtils.zeroSum(sample: AverageableValue): AverageableValue
	local sampleType = typeof(sample)
	if sampleType == "Vector3" then
		return Vector3.zero
	elseif sampleType == "Vector2" then
		return Vector2.zero
	end
	return 0
end

function JecsImmediateHookUtils.quotient(sum: AverageableValue, count: number): AverageableValue
	if count <= 0 then
		return sum
	end
	return (sum :: any) / count
end

function JecsImmediateHookUtils.internalValue(value: any): any
	if typeof(value) == "Color3" then
		return Vector3.new(value.R, value.G, value.B)
	end
	return value
end

function JecsImmediateHookUtils.externalValue(internal: any, asColor3: boolean): any
	if asColor3 and typeof(internal) == "Vector3" then
		return Color3.new(math.clamp(internal.X, 0, 1), math.clamp(internal.Y, 0, 1), math.clamp(internal.Z, 0, 1))
	end
	return internal
end

function JecsImmediateHookUtils.usesColor3(goal: any?, value: any?): boolean
	if goal ~= nil then
		return typeof(goal) == "Color3"
	end
	if value ~= nil then
		return typeof(value) == "Color3"
	end
	return false
end

function JecsImmediateHookUtils.forceCleanupHooks(rt: ImmediateRuntime_Jecs_Hooks)
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

function JecsImmediateHookUtils.forceCleanupHooksOfFile(rt: ImmediateRuntime_Jecs_Hooks, filename: string)
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

function JecsImmediateHookUtils.evaluateAndCleanupHooks(rt: ImmediateRuntime_Jecs_Hooks)
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

function JecsImmediateHookUtils.flushHookRuntimeBuffers(rt: ImmediateRuntime_Jecs_Hooks)
	for _et, hookState, _ in rt.world:query(rt.comps.HookState, rt.comps.HookRuntimeBuffer) do
		if hookState.calledThisFrame then
			table.clear(hookState.tab)
		end
		hookState.calledThisFrame = false
	end
end

return JecsImmediateHookUtils
