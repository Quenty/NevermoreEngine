--[=[
	@class PerformanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local PerformanceUtils = {}

local timeStack = {}
local counters = {}
local objectStacks = {}

function PerformanceUtils.profileTimeBegin(label)
	table.insert(timeStack, {
		label = label;
		startTime = os.clock()
	})

	return function()
		PerformanceUtils.profileTimeEnd()
	end
end

function PerformanceUtils.profileTimeEnd()
	local value = table.remove(timeStack)
	if value then
		PerformanceUtils.incrementCounter(value.label, os.clock() - value.startTime)
	end
end

function PerformanceUtils.incrementCounter(label, amount)
	amount = amount or 1
	PerformanceUtils.getOrCreateCounter(label).total += amount

	return function()
		PerformanceUtils.getOrCreateCounter(label).total -= amount
	end
end

function PerformanceUtils.readCounter(label)
	return PerformanceUtils.getOrCreateCounter(label).total
end

function PerformanceUtils.getOrCreateCounter(label)
	assert(type(label) == "string", "Bad label")

	local data = counters[label]
	if data then
		return data
	else
		counters[label] = {
			total = 0;
			formatter = tostring;
		}

		return counters[label]
	end
end

function PerformanceUtils.setLabelFormat(label, formatter)
	PerformanceUtils.getOrCreateCounter(label).formatter = formatter
end

function PerformanceUtils.formatAsMilliseconds(value)
	return value*1000 .. " ms"
end

function PerformanceUtils.formatAsCalls(value)
	return String.addCommas(value) .. " calls"
end

function PerformanceUtils.countCalls(label, object, method)
	PerformanceUtils.setLabelFormat(label, PerformanceUtils.formatAsCalls)

	local original = object[method]
	object[method] = function(...)
		PerformanceUtils.incrementCounter(label, 1)

		return original(...)
	end
end

function PerformanceUtils.countCallTime(label, object, method)
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


function PerformanceUtils.countObject(label, object)
	PerformanceUtils.countCalls(label .. "_new", object, "new")
	PerformanceUtils.countCalls(label .. "_destroy", object, "Destroy")
end

function PerformanceUtils.trackObjectConstruction(object)
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
		for stackTrace, _ in pairs(objectStackTraceMap) do
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

		for i=1, toShow do
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

function PerformanceUtils.printAll()
	local keys = {}
	for label, _ in pairs(counters) do
		table.insert(keys, label)
	end
	table.sort(keys)

	for _, label in pairs(keys) do
		local data = counters[label]

		print(label, data.formatter(data.total))
	end
end

return PerformanceUtils