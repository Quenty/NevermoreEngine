--!nonstrict
local require = require(script.Parent.loader).load(script)

local ImmediateTypes = require("ImmediateTypes")
local Jecs = require("Jecs")
local Jecst = require("Jecst")
local Maid = require("Maid")

local WARN_HOOK_CLEANUP = false

local ImmediateHookUtils = {}

function ImmediateHookUtils._getOrCreateHookState<T>(
	rt: ImmediateTypes.ImmediateRuntime,
	discriminator: any,
	cleanupIfTrue: ((state: T) -> boolean)?,
	runtimePersistent: boolean? -- be very careful using this. will not be cleaned up
): (T, Maid.Maid, Jecst.Entity)
	local _filename = debug.info(3, "s")
	local _line = debug.info(3, "l")
	local _firstKey = `{_filename}:{_line}`

	-- Order of calls logged per file/line.
	-- If multiple hooks are called in the same line, we default to discriminating
	-- by the order of calls (so if you omitted the discriminator in a loop, you'd get a
	-- unique hook state per iteration).
	if not rt._hookOrderOfCalls then
		rt._hookOrderOfCalls = {}
	end
	if not rt._hookOrderOfCalls[_firstKey] then
		rt._hookOrderOfCalls[_firstKey] = 0
	end
	rt._hookOrderOfCalls[_firstKey] = rt._hookOrderOfCalls[_firstKey] + 1

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
		_discriminator = `__call_{rt._hookOrderOfCalls[_firstKey]}`
	end

	if not rt._hookStateEntities then
		rt._hookStateEntities = {}
	end
	if not rt._hookStateEntities[_firstKey] then
		rt._hookStateEntities[_firstKey] = {}
	end

	-- Find the hook state.
	local hookStateEntity = rt._hookStateEntities[_firstKey][_discriminator]
	if hookStateEntity then
		if not rt.world:contains(hookStateEntity) then
			rt._hookStateEntities[_firstKey][_discriminator] = nil
			rt._hookOrderOfCalls[_firstKey] = nil
			error(`Hook state entity for {_filename}:{_line} with discriminator {_discriminator} is not in the world`)
		end
		local hookMaid = rt.world:get(hookStateEntity, rt.Components.Maid)
		local mhs = rt.world:get(hookStateEntity, rt.Components.MetaHookState)
		mhs.flagForCleanup = false
		return rt.world:get(hookStateEntity, rt.Components.HookState) :: T, hookMaid, hookStateEntity
	end

	-- If not, create it.
	local newHookEntity = rt.world:entity()
	if entityToParentTo then
		rt.world:add(newHookEntity, Jecs.pair(rt.Components.ChildOf, entityToParentTo))
	end
	if runtimePersistent then
		rt.world:add(newHookEntity, rt.Components.HookRuntimeBuffer)
	end
	local newHookState = {}
	local maid = Maid.new()

	-- The actual cleanup task should be defined in the returned maid.
	-- This one only clears the table.
	maid:GiveTask(function()
		rt._hookStateEntities[_firstKey][_discriminator] = nil
		rt._hookOrderOfCalls[_firstKey] = nil
		if WARN_HOOK_CLEANUP then
			warn(`Cleaned up hook state for {_filename}:{_line} with discriminator {_discriminator}`)
		end
	end)
	rt.world:set(newHookEntity, rt.Components.MetaHookState, {
		filename = _filename,
		line = _line,
		discriminator = discriminator,
		flagForCleanup = false,
		shouldCleanupCallback = cleanupIfTrue,
		runtimePersistent = runtimePersistent,
	})
	rt.world:set(newHookEntity, rt.Components.Maid, maid)
	rt.world:set(newHookEntity, rt.Components.HookState, newHookState)
	rt._hookStateEntities[_firstKey][_discriminator] = newHookEntity

	return rt.world:get(newHookEntity, rt.Components.HookState) :: T, maid, newHookEntity
end

return ImmediateHookUtils
