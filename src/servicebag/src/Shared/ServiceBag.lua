--!strict
--[=[
	Service bags handle recursive initialization of services, and the
	retrieval of services from a given source. This allows the composition
	of services without the initialization of those services becoming a pain,
	which makes refactoring downstream services very easy.

	This also allows multiple copies of a service to exist at once, although
	many services right now are not designed for this.

	```lua
	local serviceBag = ServiceBag.new()

	serviceBag:GetService({
		Init = function(self)
			print("Service initialized")
		end;
	})
	serviceBag:Init()
	serviceBag:Start()
	```

	:::tip
	ServiceBag does not allow services to yield on :Init() or :Start(), nor
	does it allow you to add services after :Init() or :Start()
	:::

	@class ServiceBag
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ServiceInitLogger = require("ServiceInitLogger")
local Signal = require("Signal")

--[=[
	@interface Service
	.Init: (serviceBag: ServiceBag) -> ()?
	.Start: () -> ()?
	.Destroy: () -> ()?
	@within ServiceBag
]=]

--[=[
	@type ServiceType Service | ModuleScript
	@within ServiceBag
]=]

local ServiceBag = setmetatable({}, BaseObject)
ServiceBag.ClassName = "ServiceBag"
ServiceBag.__index = ServiceBag

export type ServiceBag =
	typeof(setmetatable(
		{} :: {
			_services: { [any]: any },
			_parentProvider: ServiceBag?,
			_serviceTypesToInitializeSet: { [any]: true }?,
			_initializedServiceTypeSet: { [any]: true },
			_initializedServiceTypeList: { any },
			_serviceTypesToStartSet: { [any]: true }?,

			_initRunAllowed: boolean,
			_destructing: boolean,
			_serviceInitLogger: ServiceInitLogger.ServiceInitLogger,
			_serviceStartLogger: ServiceInitLogger.ServiceInitLogger,

			_destroyingSignal: Signal.Signal<()>,

			_initFrameBudget: number?,
			_frameStartClock: number,
			_budgetPauses: number,
			_budgetLongestStretch: number,
			_budgetWaitingThreads: { [thread]: true },
		},
		{} :: typeof({ __index = ServiceBag })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new ServiceBag

	@param parentProvider ServiceBag? -- Optional parent provider to find services in
	@return ServiceBag
]=]
function ServiceBag.new(parentProvider: ServiceBag?): ServiceBag
	local self: ServiceBag = setmetatable(BaseObject.new() :: any, ServiceBag)

	self._services = {}
	self._parentProvider = parentProvider

	self._serviceTypesToInitializeSet = {}
	self._initializedServiceTypeSet = {}
	self._initializedServiceTypeList = {}
	self._serviceTypesToStartSet = {}

	self._initRunAllowed = false
	self._destructing = false

	self._initFrameBudget = nil
	self._frameStartClock = 0
	self._budgetPauses = 0
	self._budgetLongestStretch = 0
	self._budgetWaitingThreads = setmetatable({}, { __mode = "k" }) :: any

	self._serviceInitLogger = ServiceInitLogger.new("initialized")
	self._serviceStartLogger = ServiceInitLogger.new("started")

	self._destroyingSignal = Signal.new()

	return self
end

--[=[
	Returns whether the value is a serviceBag

	@param value ServiceBag?
	@return boolean
]=]
function ServiceBag.isServiceBag(value: any): boolean
	return type(value) == "table" and value.ClassName == "ServiceBag"
end

--[=[
	Prints out initialization stack trace - helpful for debugging
	and diagnostics.
]=]
function ServiceBag.PrintInitialization(self: ServiceBag)
	self._serviceInitLogger:Print()
	self._serviceStartLogger:Print()
end

--[=[
	Retrieves the service, ensuring initialization if we are in
	the initialization phase.

	@param serviceType ServiceType
	@return any
]=]
function ServiceBag.GetService<T>(self: ServiceBag, serviceType: T): T
	if typeof(serviceType) == "Instance" then
		serviceType = (require :: any)(serviceType)
	end

	if type(serviceType) ~= "table" then
		error(
			string.format(
				"Bad serviceType definition of type %s of type %s",
				tostring(serviceType),
				typeof(serviceType)
			)
		)
	end

	local service = self._services[serviceType]
	if service then
		self:_ensureInitialization(serviceType)
		return self._services[serviceType]
	else
		if self._parentProvider then
			return self._parentProvider:GetService(serviceType)
		end

		-- Try to add the service if we're still initializing services
		self:_addServiceType(serviceType)
		self:_ensureInitialization(serviceType)
		return self._services[serviceType]
	end
end

--[=[
	Returns whether the service bag has the service.
	@param serviceType ServiceType
	@return boolean
]=]
function ServiceBag.HasService<T>(self: ServiceBag, serviceType: T): boolean
	if typeof(serviceType) == "Instance" then
		serviceType = (require :: any)(serviceType)
	end

	if self._services[serviceType] then
		return true
	else
		return false
	end
end

--[=[
	Spreads [ServiceBag.Init] and [ServiceBag.Start] over several frames. Before each service
	initializes or starts, if the current frame has already spent `seconds`, the bag waits a frame
	first. Services still initialize and start in the same order; this only stops a large bag from
	doing all of its work in one long frame, such as a client joining with a hundred or more
	services.

	A service that yields in its own `Init` still errors. With a budget set, [ServiceBag.Init] and
	[ServiceBag.Start] yield, so call them from a thread that can yield.

	```lua
	local serviceBag = ServiceBag.new()
	serviceBag:SetInitFrameBudget(0.012)
	serviceBag:GetService(require("MyServiceClient"))
	serviceBag:Init()
	serviceBag:Start()
	```

	@param seconds number? -- Work allowed per frame. `nil` (the default) does everything at once.
]=]
function ServiceBag.SetInitFrameBudget(self: ServiceBag, seconds: number?): ()
	assert(seconds == nil or (type(seconds) == "number" and seconds > 0), "Bad seconds")
	assert(not self._initRunAllowed and self._serviceTypesToInitializeSet, "Set the budget before Init")

	self._initFrameBudget = seconds
end

--[=[
	How many frames [ServiceBag.Init] and [ServiceBag.Start] waited because of the frame budget,
	and the longest stretch of work between two waits, in seconds.

	@return (number, number)
]=]
function ServiceBag.GetFrameBudgetStats(self: ServiceBag): (number, number)
	if self._frameStartClock == 0 then
		return self._budgetPauses, self._budgetLongestStretch
	end

	return self._budgetPauses, math.max(self._budgetLongestStretch, os.clock() - self._frameStartClock)
end

function ServiceBag._pauseIfOverBudget(self: ServiceBag): ()
	local budget = self._initFrameBudget
	if not budget or os.clock() - self._frameStartClock < budget then
		return
	end

	local thread = coroutine.running()
	self._budgetPauses += 1
	self._budgetLongestStretch = math.max(self._budgetLongestStretch, os.clock() - self._frameStartClock)
	self._budgetWaitingThreads[thread] = true
	task.wait()
	self._budgetWaitingThreads[thread] = nil
	self._frameStartClock = os.clock()
end

--[=[
	Initializes the service bag and ensures recursive initialization
	can occur
]=]
function ServiceBag.Init(self: ServiceBag)
	assert(not self._initRunAllowed, "Already initializing")
	assert(self._serviceTypesToInitializeSet, "Already initialized")
	self._initRunAllowed = true
	self._frameStartClock = os.clock()

	while next(self._serviceTypesToInitializeSet) do
		local serviceType = next(self._serviceTypesToInitializeSet)
		self._serviceTypesToInitializeSet[serviceType] = nil

		self:_ensureInitialization(serviceType)
	end

	self._serviceTypesToInitializeSet = nil
end

--[=[
	Starts the service bag and all services
]=]
function ServiceBag.Start(self: ServiceBag)
	assert(self._serviceTypesToStartSet, "Already started")
	assert(not self._serviceTypesToInitializeSet, "Not initialized yet. Call serviceBag:Init() first.")

	self._initRunAllowed = false
	self._frameStartClock = os.clock()

	while next(self._serviceTypesToStartSet) do
		-- With a frame budget, :Start() is spread over frames too (between services only).
		self:_pauseIfOverBudget()
		local serviceType = table.remove(self._serviceTypesToStartSet)
		local service = assert(self._services[serviceType], "No service")
		local serviceName = self:_getServiceName(serviceType)

		if service.Start then
			local current
			task.spawn(function()
				local stopClock = self._serviceStartLogger:StartInitClock(serviceName)

				debug.setmemorycategory(serviceName)
				current = coroutine.running()
				service:Start()

				stopClock()
			end)

			local isDead = coroutine.status(current) == "dead"
			if not isDead then
				error(debug.traceback(current, string.format("Starting service %q yielded", serviceName)))
			end
		end
	end

	self._serviceTypesToStartSet = nil
end

function ServiceBag._getServiceName(_self: ServiceBag, serviceType): string
	local serviceName
	pcall(function()
		serviceName = serviceType.ServiceName
	end)
	if type(serviceName) == "string" then
		return serviceName
	end

	return tostring(serviceType)
end

--[=[
	Returns whether the service bag has fully started or not.
	@return boolean
]=]
function ServiceBag.IsStarted(self: ServiceBag): boolean
	return self._serviceTypesToStartSet == nil
end

--[=[
	Creates a scoped service bag, where services within the scope will not
	be accessible outside of the scope.

	@return ServiceBag
]=]
function ServiceBag.CreateScope(self: ServiceBag): ServiceBag
	local provider: ServiceBag = ServiceBag.new(self)

	self:_addServiceType(provider)

	-- Remove from parent provider
	self._maid[provider] = provider._destroyingSignal:Connect(function()
		self._maid[provider] = nil
		self._services[provider] = nil
	end)

	return provider
end

-- Adds a service to this provider only
function ServiceBag._addServiceType<T>(self: ServiceBag, serviceType: T)
	if self._destructing then
		local serviceName = self:_getServiceName(serviceType)
		error(string.format("Cannot query service %q after ServiceBag is cleaned up", serviceName))
		return
	end

	if self:IsStarted() then
		local hint =
			'HINT: Be sure to call serviceBag:GetService(require("MyService")) either before calling serviceBag:Init() or during serviceBag:Init() (within another service:Init)'
		error(string.format("Already started, cannot add %q. \n%s", self:_getServiceName(serviceType), hint))
		return
	end

	-- Already added
	if self._services[serviceType] then
		return
	end

	-- Construct a new version of this service so we're isolated
	local service = setmetatable({}, { __index = serviceType })
	self._services[serviceType] = service

	self:_ensureInitialization(serviceType)
end

function ServiceBag._ensureInitialization<T>(self: ServiceBag, serviceType: T)
	if self._initializedServiceTypeSet[serviceType] then
		return
	end

	if self._destructing then
		local serviceName = self:_getServiceName(serviceType)
		error(string.format("Cannot initialize service %q after ServiceBag is cleaned up", serviceName))
		return
	end

	if self._initRunAllowed then
		if self._serviceTypesToInitializeSet then
			self._serviceTypesToInitializeSet[serviceType] = nil
		end

		self._initializedServiceTypeSet[serviceType] = true
		self:_pauseIfOverBudget()
		self:_initService(serviceType)
	elseif self._serviceTypesToInitializeSet then
		self._serviceTypesToInitializeSet[serviceType] = true
	else
		local serviceName = self:_getServiceName(serviceType)
		error(string.format("Cannot initialize service %q after start", serviceName))
	end
end

function ServiceBag._initService(self: ServiceBag, serviceType)
	assert(self._serviceTypesToStartSet, "ServiceBag cannot start")

	local service = assert(self._services[serviceType], "No service")
	local serviceName = self:_getServiceName(serviceType)

	if service.Init then
		local current
		local done = false
		local waiter: thread? = nil
		task.spawn(function()
			debug.setmemorycategory(serviceName)

			local stopClock = self._serviceInitLogger:StartInitClock(serviceName)

			current = coroutine.running()

			-- Caught so that an Init that errors still counts as finished, as it does without a
			-- budget, and a thread waiting on it after a budget pause is resumed instead of hanging.
			local ok, err = xpcall(service.Init, debug.traceback, service, self)
			if ok then
				stopClock()
			end

			done = true
			if waiter then
				task.spawn(waiter)
			end

			if not ok then
				error(err, 0)
			end
		end)

		if not done then
			local waitingThreads = self._budgetWaitingThreads
			if waitingThreads[current] then
				-- Paused by the frame budget, or waiting on a service that was. Wait for it to finish,
				-- marked the same way, so that anything waiting on this thread waits too.
				local thread = coroutine.running()
				waiter = thread
				waitingThreads[thread] = true
				coroutine.yield()
				waitingThreads[thread] = nil
			else
				error(debug.traceback(current, string.format("Initializing service %q yielded", serviceName)))
			end
		end
	end

	-- Init-completion order is a valid dependency order (a service's dependencies finish
	-- initializing before it does, via the GetService recursion), so record it for teardown.
	table.insert(self._initializedServiceTypeList, serviceType)
	table.insert(self._serviceTypesToStartSet, serviceType)
end

--[=[
	Cleans up the service bag and all services that have been
	initialized in the service bag.
]=]
function ServiceBag.Destroy(self: ServiceBag)
	if self._destructing then
		return
	end

	local super = getmetatable(ServiceBag)

	self._destructing = true

	self._destroyingSignal:Fire()
	self._destroyingSignal:Destroy()

	self:_destructServices()

	super.Destroy(self :: any)
end

function ServiceBag._destructServices(self: ServiceBag)
	local services = self._services

	-- Destroy in reverse initialization order, so dependents tear down before the dependencies
	-- they may still be writing to (see _initService: init-completion order is a dependency order).
	local initializedList = self._initializedServiceTypeList
	for index = #initializedList, 1, -1 do
		local serviceType = initializedList[index]
		local service = services[serviceType]
		if service ~= nil then
			services[serviceType] = nil
			self:_destructService(serviceType, service)
		end
	end

	-- Anything left never finished initializing; destroy it in arbitrary order, as before.
	local serviceType, service = next(services)
	while service ~= nil do
		services[serviceType] = nil

		if not (self._serviceTypesToInitializeSet and self._serviceTypesToInitializeSet[serviceType]) then
			self:_destructService(serviceType, service)
		end

		serviceType, service = next(services)
	end
end

function ServiceBag._destructService(self: ServiceBag, serviceType, service)
	local serviceName = self:_getServiceName(serviceType)

	local current
	task.spawn(function()
		debug.setmemorycategory(serviceName)
		current = coroutine.running()

		if service.Destroy then
			service:Destroy()
		end
	end)

	local isDead = coroutine.status(current) == "dead"
	if not isDead then
		warn(debug.traceback(current, string.format("Destroying service %q yielded", serviceName)))
	end
end

return ServiceBag
