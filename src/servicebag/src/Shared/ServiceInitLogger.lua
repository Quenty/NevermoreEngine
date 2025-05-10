--!strict
--[=[
	@class ServiceInitLogger
]=]

local EPSILON = 1e-6

local ServiceInitLogger = {}
ServiceInitLogger.ClassName = "ServiceInitLogger"
ServiceInitLogger.__index = ServiceInitLogger

type LogEntry = {
	name: string,
	children: { LogEntry },
	log: string?,
}

export type ServiceInitLogger = typeof(setmetatable(
	{} :: {
		_action: string,
		_rootNode: LogEntry,
		_stack: { LogEntry },
		_totalTimeUsed: number,
		_initIndent: number,
		_totalServices: number,
	},
	{} :: typeof({ __index = ServiceInitLogger })
))

function ServiceInitLogger.new(action: string): ServiceInitLogger
	local self = setmetatable({}, ServiceInitLogger)

	assert(type(action) == "string", "Bad action")

	self._action = action
	self._rootNode = {
		name = "ROOT",
		children = {},
	} :: LogEntry
	self._stack = { self._rootNode }
	self._totalTimeUsed = 0
	self._initIndent = 0
	self._totalServices = 0

	return self
end

function ServiceInitLogger.StartInitClock(self: ServiceInitLogger, serviceName: string)
	assert(type(serviceName) == "string", "serviceName")

	local startTime: number = os.clock()

	local initialIndent: number = self._initIndent
	local initialTotalTimeUsed: number = self._totalTimeUsed
	local initialTotalServices: number = self._totalServices

	self._initIndent = initialIndent + 1
	self._totalServices = self._totalServices + 1

	local parent: LogEntry = self._stack[#self._stack]
	local entry: LogEntry = {
		name = serviceName,
		children = {},
		log = string.format("%s%sService is not loaded", string.rep("  ", initialIndent), serviceName),
	}
	table.insert(parent.children, entry)
	table.insert(self._stack, entry)

	return function()
		for i = #self._stack, 1, -1 do
			if self._stack[i] == entry then
				table.remove(self._stack, i)
				break
			end
		end

		local timeUsed = (os.clock() - startTime)
		local otherServiceTime = self._totalTimeUsed - initialTotalTimeUsed
		local internalTimeUsed = timeUsed - otherServiceTime
		local totalServices = self._totalServices - initialTotalServices - 1

		self._totalTimeUsed = self._totalTimeUsed + internalTimeUsed
		self._initIndent = self._initIndent - 1

		if math.abs(internalTimeUsed - timeUsed) <= EPSILON then
			entry.log = string.format(
				"%sService %s %s in %0.2f ms",
				string.rep("  ", initialIndent),
				serviceName,
				self._action,
				1000 * internalTimeUsed
			)
		else
			entry.log = string.format(
				"%sService %s %s in %0.2f ms (%0.2f ms total for %d descendants)",
				string.rep("  ", initialIndent),
				serviceName,
				self._action,
				1000 * internalTimeUsed,
				1000 * timeUsed,
				totalServices
			)
		end
	end
end

function ServiceInitLogger.Print(self: ServiceInitLogger)
	local function recurse(node: LogEntry)
		print(node.log)
		for _, childNode in node.children do
			recurse(childNode)
		end
	end

	for _, child in self._rootNode.children do
		recurse(child)
	end
end

return ServiceInitLogger
