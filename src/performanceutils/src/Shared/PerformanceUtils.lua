--[=[
	@class PerformanceUtils
]=]

local require = require(script.Parent.loader).load(script)

local String = require("String")

local PerformanceUtils = {}

local timeStack = {}
local counters = {}

function PerformanceUtils.profileTimeBegin(label)
	table.insert(timeStack, {
		label = label;
		startTime = os.clock()
	})
end

function PerformanceUtils.profileTimeEnd()
	local value = table.remove(timeStack)
	if value then
		PerformanceUtils.incrementCounter(value.label, os.clock() - value.startTime)
	end
end

function PerformanceUtils.incrementCounter(label, amount)
	PerformanceUtils.getOrCreateCounter(label).total += amount
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