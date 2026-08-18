--!strict
--[=[
	@class ImmediateScheduler

	A basic scheduler that supports:
	
	* pretick
	* presystem
	* postsystem
	* posttick

	ordering.

	This doesn't handle hot reloading; some hot-reload service can interact with
	a scheduler's APIs to add/remove systems.

	You determine when entire "ticks" happen (usually by hooking it up to
	PreRender, or you can just manually call tick() a bunch in one go for unit
	tests).
]=]
local rawrequire = require
local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ImmediateCoreUtils = require("ImmediateCoreUtils")

local ImmediateScheduler = setmetatable({}, BaseObject)
ImmediateScheduler.ClassName = "ImmediateScheduler"
ImmediateScheduler.__index = ImmediateScheduler

type ImmediateRuntime = ImmediateCoreUtils.ImmediateRuntime

--[[
	https://create.roblox.com/docs/performance-optimization/microprofiler/task-scheduler

	For reference:
	RunService.PreAnimation
	RunService.PreSimulation
	RunService.PostSimulation
	RunService.Heartbeat
	RunService.PreRender

	One scheduler = one contiguous block, run from ONE event. Hook Tick() onto
	any of those or any event/signal. Or just manually call it. Multiple times
	maybe. Up to you.
]]

--[=[
	A system registered with a scheduler.

	One scheduler runs one contiguous, priority-sorted block per Tick(). Hooking
	that Tick to an event is the caller's job, so a PreRender scheduler and a
	PreAnimation scheduler are completely separate blocks.

	@class ImmediateSchedulableSystem
]=]
export type ImmediateSchedulableSystem<Rt> = {
	-- The actual code it'll run. The runtime always comes first.
	system: (rt: Rt, ...any) -> (),

	-- Sort order inside the tick. Lower numbers run first; ties break on `name`.
	-- defaults to 0. so if you really want to make sure yours runs first, go negative
	priority: number?,

	-- Required for replacement/non-duplicate reasons.
	-- RegisterDescendantModuleScripts fills this from the ModuleScript name if omitted.
	name: string?,

	-- Optional opt-out of protected calls.
	notProtected: boolean?,

	-- Hard-coded slot topology: preTick -> (preSystem -> system -> postSystem)* -> postTick.
	-- Flags select which slot(s) a system runs in; a system with no flags runs
	-- in the main `system` slot. `priority` is relative to the whole block.
	preSystem: boolean?,
	postSystem: boolean?,
	preTick: boolean?,
	postTick: boolean?,

	-- Called when the system is unregistered or the scheduler is destroyed.
	Destroy: (() -> ())?,
}

type SchedulableSystem = ImmediateSchedulableSystem<ImmediateRuntime>

export type ImmediateScheduler =
	typeof(setmetatable(
		{} :: {
			_systemDictionary: { [string]: SchedulableSystem },
			_sortFlag: boolean,
			_sorted_systems: { SchedulableSystem },
			_sorted_preSystem: { SchedulableSystem },
			_sorted_postSystem: { SchedulableSystem },
			_sorted_preTick: { SchedulableSystem },
			_sorted_postTick: { SchedulableSystem },
		},
		{} :: typeof({ __index = ImmediateScheduler })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new ImmediateScheduler.

	@return ImmediateScheduler
]=]
function ImmediateScheduler.new(): ImmediateScheduler
	local self = setmetatable(BaseObject.new() :: any, ImmediateScheduler)

	self._systemDictionary = {}

	-- If set to true, will re-order systems for next tick
	self._sortFlag = false

	-- Each of these are guaranteed sorted in priority.
	self._sorted_systems = {}
	self._sorted_preSystem = {}
	self._sorted_postSystem = {}
	self._sorted_preTick = {}
	self._sorted_postTick = {}

	return self
end

local function _isMiddleware(system: SchedulableSystem): boolean
	return system.preSystem == true or system.postSystem == true or system.preTick == true or system.postTick == true
end

local function _systemSortKey(system: SchedulableSystem): number
	local priority = if typeof(system.priority) == "number" then system.priority else 0
	return priority
end

local function _sortSystemsInPlace(array: { SchedulableSystem })
	table.sort(array, function(a, b)
		local aPriority = _systemSortKey(a)
		local bPriority = _systemSortKey(b)
		return aPriority < bPriority
	end)
end

-- definitely not optimized or anything but whatever
-- shouldn't be done that frequently
function ImmediateScheduler._sortSystemArrays(self: ImmediateScheduler)
	table.clear(self._sorted_systems)
	table.clear(self._sorted_preSystem)
	table.clear(self._sorted_postSystem)
	table.clear(self._sorted_preTick)
	table.clear(self._sorted_postTick)

	for _systemName, systemTable in pairs(self._systemDictionary) do
		if systemTable.preTick then
			table.insert(self._sorted_preTick, systemTable)
		end
		if systemTable.preSystem then
			table.insert(self._sorted_preSystem, systemTable)
		end
		if systemTable.postTick then
			table.insert(self._sorted_postTick, systemTable)
		end
		if systemTable.postSystem then
			table.insert(self._sorted_postSystem, systemTable)
		end
		if not _isMiddleware(systemTable) then
			table.insert(self._sorted_systems, systemTable)
		end
	end

	_sortSystemsInPlace(self._sorted_systems)
	_sortSystemsInPlace(self._sorted_preSystem)
	_sortSystemsInPlace(self._sorted_postSystem)
	_sortSystemsInPlace(self._sorted_preTick)
	_sortSystemsInPlace(self._sorted_postTick)

	self._sortFlag = false
end

local SYSTEM_ERROR_SUPPRESS_SECONDS = 10
local SYSTEM_OVERALL_SUPPRESS_ERRORS = 5

function ImmediateScheduler._runProtectedSystem(
	_self: ImmediateScheduler,
	rt: ImmediateRuntime,
	system: SchedulableSystem,
	...
)
	local errorLog = rt.errorlog
	local ok, errmsg = xpcall(function(...)
		if rt.DEBUG then
			local args = table.pack(...)
			local thread = coroutine.create(function()
				system.system(rt, unpack(args, 1, args.n))
			end)
			local resumed, err = coroutine.resume(thread)
			if not resumed then
				error(err)
			end
			if coroutine.status(thread) ~= "dead" then
				local traceback = debug.traceback(thread)
				task.cancel(thread)
				error(`RxECS system {system.name} yielded:\n{traceback}`)
			end
		else
			system.system(rt, ...)
		end
	end, function(err)
		return debug.traceback(err, 2)
	end, ...)
	if not ok then
		local key = `{system.name}: {errmsg}`
		local foundEntry = errorLog[key]
		if not foundEntry then
			local newEntry = {
				count = 0,
				lastShoutedAt = 0,
				systemName = system.name,
				traceback = errmsg,
			}
			errorLog[key] = newEntry
			foundEntry = newEntry
		end

		foundEntry.count += 1

		-- We usually only care about the very first error.
		-- Other errors are cascading.
		-- So we have an *overall* cooldown, for any error at all.
		local weErroredAfterCooldown = os.clock() - foundEntry.lastShoutedAt >= SYSTEM_ERROR_SUPPRESS_SECONDS
		local weErroredAfterOverallCooldown = os.clock() - (errorLog.lastErrorShout or 0)
			>= SYSTEM_OVERALL_SUPPRESS_ERRORS

		if weErroredAfterCooldown and weErroredAfterOverallCooldown then
			task.spawn(error, `[RxECS] {key}, traceback: {foundEntry.traceback}`)
			foundEntry.lastShoutedAt = os.clock()
			errorLog.lastErrorShout = os.clock()
		end
	end
end

function ImmediateScheduler.Tick(self: ImmediateScheduler, rt: ImmediateRuntime)
	if self._sortFlag == true then
		self:_sortSystemArrays()
	end

	for _, systemTable in self._sorted_preTick do
		self:_runProtectedSystem(rt, systemTable)
		rt.previousRawSystem = systemTable
	end
	for _, systemTable in self._sorted_systems do
		for _, preSystemTable in self._sorted_preSystem do
			self:_runProtectedSystem(rt, preSystemTable)
			rt.previousRawSystem = preSystemTable
		end
		self:_runProtectedSystem(rt, systemTable)
		rt.previousRawSystem = systemTable
		rt.previousSystem = systemTable
		for _, postSystemTable in self._sorted_postSystem do
			self:_runProtectedSystem(rt, postSystemTable)
			rt.previousRawSystem = postSystemTable
		end
	end
	for _, systemTable in self._sorted_postTick do
		self:_runProtectedSystem(rt, systemTable)
		rt.previousRawSystem = systemTable
	end
end

function ImmediateScheduler.RegisterSystem(self: ImmediateScheduler, systemTable: SchedulableSystem)
	-- TODO: upsert into the schedule by `name`, then sort by priority/name.
	local systemName = assert(systemTable.name, "ImmediateSchedulableSystem requires name")
	if self._systemDictionary[systemName] then
		self:UnregisterSystem(systemName)
	end
	self._systemDictionary[systemName] = systemTable
	self._sortFlag = true
	return function()
		self:UnregisterSystem(systemName)
	end
end

-- helper method to quickly grab all systems modules under one folder or something
function ImmediateScheduler.RegisterDescendantModuleScripts(self: ImmediateScheduler, instance: Instance)
	for _, v in instance:GetDescendants() do
		if v:IsA("ModuleScript") and v.Name ~= "loader" then
			local loaded = rawrequire(v)
			if type(loaded) == "table" and type(loaded.system) == "function" then
				if loaded.name == nil then
					loaded.name = v.Name
				end
				self:RegisterSystem(loaded)
			end
		end
	end
end

function ImmediateScheduler.UnregisterSystem(self: ImmediateScheduler, systemName: string)
	-- it's just behavior anyway just BIE BYE EBYBEYBEYE
	local targetSystem = self._systemDictionary[systemName]
	if targetSystem then
		if targetSystem.Destroy and typeof(targetSystem.Destroy) == "function" then
			targetSystem.Destroy()
		end
		self._systemDictionary[systemName] = nil
	end
	self._sortFlag = true
end

function ImmediateScheduler.Destroy(self: ImmediateScheduler)
	table.clear(self._systemDictionary)
	table.clear(self._sorted_systems)
	table.clear(self._sorted_preSystem)
	table.clear(self._sorted_postSystem)
	table.clear(self._sorted_preTick)
	table.clear(self._sorted_postTick)
end

return ImmediateScheduler
