--strict
--[=[
	@class PerformanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local PerformanceUtils = {}

local timeStack = {}
local counters = {}
local objectStacks = {}

type Formatter = (number) -> string
export type CounterData = {
	total: number,
	formatter: Formatter,
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
		counters[label] = {
			total = 0,
			formatter = tostring,
		}

		return counters[label]
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