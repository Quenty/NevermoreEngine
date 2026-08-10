--!strict
--[=[
	@class PerformanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local PerformanceUtils = {}

local timeStack: { ProfilerStamp } = {}
local counters: { [string]: CounterData } = {}
local objectStacks = {}
local objectLifetimeTrackers = setmetatable({}, { __mode = "k" })
local lifetimeSiteCounts: { [string]: { [string]: number } } = {}
local lifetimeSiteLastCounts: { [string]: { [string]: number } } = {}

type Formatter = (number) -> string
export type CounterData = {
	total: number,
	formatter: Formatter,
}
export type ProfilerStamp = {
	label: string,
	startTime: number,
}

function PerformanceUtils.profileTimeBegin(label: string): () -> ()
	table.insert(timeStack, {
		label = label,
		startTime = os.clock(),
	})

	return function()
		PerformanceUtils.profileTimeEnd()
	end
end

function PerformanceUtils.profileTimeEnd(): ()
	local value = table.remove(timeStack)
	if value then
		PerformanceUtils.incrementCounter(value.label, os.clock() - value.startTime)
	end
end

function PerformanceUtils.incrementCounter(label: string, amount: number?): () -> ()
	local change = amount or 1
	PerformanceUtils.getOrCreateCounter(label).total += change

	return function()
		PerformanceUtils.getOrCreateCounter(label).total -= change
	end
end

function PerformanceUtils.readCounter(label: string): number
	return PerformanceUtils.getOrCreateCounter(label).total
end

function PerformanceUtils.getOrCreateCounter(label: string): CounterData
	assert(type(label) == "string", "Bad label")

	local data = counters[label]
	if data then
		return data
	else
		local created: CounterData = {
			total = 0,
			formatter = tostring :: any,
		}
		counters[label] = created
		return created
	end
end

function PerformanceUtils.setLabelFormat(label: string, formatter: Formatter)
	PerformanceUtils.getOrCreateCounter(label).formatter = formatter
end

function PerformanceUtils.formatAsMilliseconds(value: number): string
	return value * 1000 .. " ms"
end

function PerformanceUtils.formatAsCalls(value: number): string
	return String.addCommas(value) .. " calls"
end

function PerformanceUtils.countCalls(label: string, object: any, method: string): ()
	PerformanceUtils.setLabelFormat(label, PerformanceUtils.formatAsCalls)

	local original = object[method]
	object[method] = function(...)
		PerformanceUtils.incrementCounter(label, 1)

		return original(...)
	end
end

function PerformanceUtils.countLibraryCalls(prefix: string, library: any): ()
	for key, value in library do
		if type(value) == "function" then
			PerformanceUtils.countCalls(prefix .. "_" .. key, library, key)
		end
	end
end

function PerformanceUtils.countCallTime(label: string, object: any, method: string): ()
	PerformanceUtils.setLabelFormat(label, PerformanceUtils.formatAsMilliseconds)
	PerformanceUtils.countCalls(label .. "_calls", object, method)

	local original = object[method]
	object[method] = function(...)
		PerformanceUtils.incrementCounter(label .. "_calls", 1)
		PerformanceUtils.profileTimeBegin(label)
		local values = table.pack(original(...))
		PerformanceUtils.profileTimeEnd()

		return unpack(values, 1, values.n)
	end
end

function PerformanceUtils.countObject(label: string, object: any): ()
	PerformanceUtils.countCalls(label .. "_new", object, "new")
	PerformanceUtils.countCalls(label .. "_destroy", object, "Destroy")
	PerformanceUtils.setLabelFormat(label .. "_total", function()
		return tostring(
			PerformanceUtils.readCounter(label .. "_new") - PerformanceUtils.readCounter(label .. "_destroy")
		)
	end)
end

local function bindCleanupAliases(object: any, cleanupAliases: { string }?)
	if not cleanupAliases then
		return
	end

	for _, alias in cleanupAliases do
		assert(type(object[alias]) == "function", string.format("Bad cleanup alias %q", alias))
		object[alias] = object.Destroy
	end
end

local SKIP_SITE_PATTERNS = {
	"PerformanceUtils",
	"Maid%.lua",
	"Maid:",
	"BaseObject%.lua",
	"BaseObject:",
}

local function shouldSkipSiteFrame(frame: string): boolean
	for _, pattern in SKIP_SITE_PATTERNS do
		if string.find(frame, pattern) then
			return true
		end
	end
	return false
end

--[=[
	Turns a construction traceback into a short "who created this" label.
	Skips instrumentation / Maid / BaseObject frames so owners like DamagePartClient
	or PipToolWheelServiceClient surface.

	@param traceback string
	@return string
]=]
function PerformanceUtils.summarizeConstructionSite(traceback: string): string
	assert(type(traceback) == "string", "Bad traceback")

	for frame in string.gmatch(traceback, "[^\r\n]+") do
		if not shouldSkipSiteFrame(frame) then
			local scriptPath: string?
			local line: string?
			local funcName: string?
			scriptPath, line, funcName = string.match(frame, "^(.-):(%d+)%s+function%s+(.+)$")
			if not scriptPath then
				scriptPath, line = string.match(frame, "^(.-):(%d+)$")
			end
			if scriptPath and line then
				local shortName = string.match(scriptPath, "([^/%.]+)$") or scriptPath
				if funcName then
					return string.format("%s:%s %s", shortName, line, funcName)
				end
				return string.format("%s:%s", shortName, line)
			end
		end
	end

	return "(unknown)"
end

local function adjustSiteCount(label: string, site: string, delta: number)
	local counts = lifetimeSiteCounts[label]
	if not counts then
		counts = {}
		lifetimeSiteCounts[label] = counts
	end

	local nextCount = (counts[site] or 0) + delta
	if nextCount > 0 then
		counts[site] = nextCount
	else
		counts[site] = nil
	end
end

--[=[
	Returns live construction-site counts for a label previously passed to
	[PerformanceUtils.trackObjectLifetime].

	@param label string
	@return { [string]: number }
]=]
function PerformanceUtils.getLifetimeSiteCounts(label: string): { [string]: number }
	assert(type(label) == "string", "Bad label")
	return lifetimeSiteCounts[label] or {}
end

--[=[
	Ranked live construction sites for a tracked label, with deltas since the
	previous ranking/dump for that label.

	@param label string
	@param limit number?
	@return { { site: string, count: number, delta: number } }
]=]
function PerformanceUtils.getLifetimeSiteRanking(
	label: string,
	limit: number?
): { { site: string, count: number, delta: number } }
	assert(type(label) == "string", "Bad label")

	local counts: { [string]: number } = lifetimeSiteCounts[label] or {}
	local lastCounts: { [string]: number } = lifetimeSiteLastCounts[label] or {}
	local ranked: { { site: string, count: number, delta: number } } = {}

	for site, count in counts do
		table.insert(ranked, {
			site = site,
			count = count,
			delta = count - (lastCounts[site] or 0),
		})
	end

	table.sort(ranked, function(a, b)
		if a.count == b.count then
			return a.delta > b.delta
		end
		return a.count > b.count
	end)

	lifetimeSiteLastCounts[label] = table.clone(counts)

	local maxShow = if type(limit) == "number" then math.max(0, limit) else 8
	local out = {}
	for i = 1, math.min(#ranked, maxShow) do
		out[i] = ranked[i]
	end
	return out
end

--[=[
	Tracks objects constructed after this method is called, grouped by construction stack.
	Cleanup aliases such as `DoCleaning`, `Disconnect`, or `Kill` are rebound to the
	instrumented `Destroy` method.

	Unlike [PerformanceUtils.countObject], cleanup of objects constructed before recording
	does not make the live total negative.

	Also classifies live objects by construction site via
	[PerformanceUtils.summarizeConstructionSite] for per-owner Maid/object tracking.

	@param label string
	@param object table
	@param cleanupAliases { string }?
	@return () -> ()
]=]
function PerformanceUtils.trackObjectLifetime(label: string, object: any, cleanupAliases: { string }?): () -> ()
	assert(type(label) == "string", "Bad label")
	assert(type(object) == "table", "Bad object")
	assert(type(object.new) == "function", "Object has no new constructor")
	assert(type(object.Destroy) == "function", "Object has no Destroy method")

	local trackers = objectLifetimeTrackers[object]
	if trackers then
		local existing = trackers[label]
		if existing then
			bindCleanupAliases(object, cleanupAliases)
			return existing
		end
	else
		trackers = {}
		objectLifetimeTrackers[object] = trackers
	end

	local stackTraceCounts: { [string]: number } = {}
	local liveStackTraceByObject = setmetatable({}, { __mode = "k" })
	local lastStackTraceCounts: { [string]: number } = {}
	local liveSiteByObject = setmetatable({}, { __mode = "k" })
	lifetimeSiteCounts[label] = lifetimeSiteCounts[label] or {}
	lifetimeSiteLastCounts[label] = lifetimeSiteLastCounts[label] or {}

	local originalNew = object.new
	object.new = function(...)
		local self = originalNew(...)
		local trace = debug.traceback()
		local site = PerformanceUtils.summarizeConstructionSite(trace)

		PerformanceUtils.incrementCounter(label .. "_new")
		stackTraceCounts[trace] = (stackTraceCounts[trace] or 0) + 1
		liveStackTraceByObject[self] = trace
		liveSiteByObject[self] = site
		adjustSiteCount(label, site, 1)

		return self
	end

	local originalDestroy = object.Destroy
	object.Destroy = function(self, ...)
		local trace = liveStackTraceByObject[self]
		if trace then
			liveStackTraceByObject[self] = nil
			PerformanceUtils.incrementCounter(label .. "_destroy")

			local remaining = (stackTraceCounts[trace] or 0) - 1
			if remaining > 0 then
				stackTraceCounts[trace] = remaining
			else
				stackTraceCounts[trace] = nil
			end
		end

		local site = liveSiteByObject[self]
		if site then
			liveSiteByObject[self] = nil
			adjustSiteCount(label, site, -1)
		end

		return originalDestroy(self, ...)
	end

	bindCleanupAliases(object, cleanupAliases)
	PerformanceUtils.setLabelFormat(label .. "_new", PerformanceUtils.formatAsCalls)
	PerformanceUtils.setLabelFormat(label .. "_destroy", PerformanceUtils.formatAsCalls)
	PerformanceUtils.setLabelFormat(label .. "_total", function()
		return tostring(
			PerformanceUtils.readCounter(label .. "_new") - PerformanceUtils.readCounter(label .. "_destroy")
		)
	end)

	local function dump()
		local retainedStackTraces = {}
		for stackTrace in stackTraceCounts do
			table.insert(retainedStackTraces, stackTrace)
		end

		table.sort(retainedStackTraces, function(a, b)
			return stackTraceCounts[a] > stackTraceCounts[b]
		end)

		local toShow = math.min(#retainedStackTraces, 5)
		if toShow == 0 then
			print("No tracked objects retained")
		end

		for i = 1, toShow do
			local stackTrace = retainedStackTraces[i]
			local count = stackTraceCounts[stackTrace]
			local delta = count - (lastStackTraceCounts[stackTrace] or 0)

			print(string.format("Retained %d (%+d since previous dump)", count, delta))
			print(stackTrace)
		end

		lastStackTraceCounts = table.clone(stackTraceCounts)
	end

	trackers[label] = dump
	return dump
end

function PerformanceUtils.trackObjectConstruction(object: any): () -> ()
	local originalNew = object["new"]
	object["new"] = function(...)
		local self = originalNew(...)

		-- HACK for observables
		local trace = debug.traceback()

		local stacks = objectStacks[object]
		if not stacks then
			stacks = {}
			objectStacks[object] = stacks
		end

		stacks[trace] = (stacks[trace] or 0) + 1
		rawset(self, "_performanceStackTrace", trace)

		return self
	end

	local originalDestroy = object["Destroy"]
	object["Destroy"] = function(self, ...)
		local trace = rawget(self, "_performanceStackTrace")
		if trace then
			local stacks = objectStacks[object]
			if not stacks then
				stacks = {}
				objectStacks[object] = stacks
			end

			stacks[trace] = (stacks[trace] or 0) - 1
			if stacks[trace] <= 0 then
				stacks[trace] = nil
			end
		end

		return originalDestroy(self, ...)
	end

	local lastObjectStackTraceMap = {}

	return function()
		local objectStackTraceMap = objectStacks[object]
		if not objectStackTraceMap then
			return
		end

		local leakedStackTraaces = {}

		-- Limit what we print
		for stackTrace, _ in objectStackTraceMap do
			table.insert(leakedStackTraaces, stackTrace)
			-- if count > 15 then
			-- 	if delta > 0 then
			-- 	end
			-- end
			--
		end

		table.sort(leakedStackTraaces, function(a, b)
			return objectStackTraceMap[a] > objectStackTraceMap[b]
		end)
		local toShow = math.clamp(#leakedStackTraaces, 0, 5)

		for i = 1, toShow do
			local stackTrace = leakedStackTraaces[i]
			local count = objectStackTraceMap[stackTrace]
			local lastCount = lastObjectStackTraceMap[stackTrace] or 0
			local delta = count - lastCount

			if delta > 0 then
				print(string.format("Added %d to total of %d", delta, count))
				print(stackTrace)
			end
		end

		lastObjectStackTraceMap = table.clone(objectStackTraceMap)
	end
end

--[=[
	Prints all counters to output.
]=]
function PerformanceUtils.printAll(): ()
	local keys = {}
	for label, _ in counters do
		table.insert(keys, label)
	end
	table.sort(keys)

	for _, label in keys do
		local data = counters[label]

		print(label, data.formatter(data.total))
	end
end

return PerformanceUtils
