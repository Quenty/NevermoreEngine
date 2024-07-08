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

	@class ServiceBag
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local BaseObject = require("BaseObject")
local ServiceInitLogger = require("ServiceInitLogger")

--[=[
	@interface Service
	.Init: function?
	.Start: function?
	.Destroy: function?
	@within ServiceBag
]=]

--[=[
	@type ServiceType Service | ModuleScript
	@within ServiceBag
]=]

local ServiceBag = setmetatable({}, BaseObject)
ServiceBag.ClassName = "ServiceBag"
ServiceBag.__index = ServiceBag

--[=[
	Constructs a new ServiceBag

	@param parentProvider ServiceBag? -- Optional parent provider to find services in
	@return ServiceBag
]=]
function ServiceBag.new(parentProvider)
	local self = setmetatable(BaseObject.new(), ServiceBag)

	self._services = {}
	self._parentProvider = parentProvider

	self._serviceTypesToInitializeSet = {}
	self._initializedServiceTypeSet = {}
	self._initRunAllowed = false
	self._destructing = false

	self._serviceInitLogger = ServiceInitLogger.new("initialized")
	self._serviceStartLogger = ServiceInitLogger.new("started")

	self._serviceTypesToStart = {}

	self._destroyingSignal = Signal.new()

	return self
end

--[=[
	Returns whether the value is a serviceBag

	@param value ServiceBag?
	@return boolean
]=]
function ServiceBag.isServiceBag(value)
	return type(value) == "table"
		and value.ClassName == "ServiceBag"
end

function ServiceBag:PrintInitialization()
	self._serviceInitLogger:Print()
	self._serviceStartLogger:Print()
end

--[=[
	Retrieves the service, ensuring initialization if we are in
	the initialization phase.

	@param serviceType ServiceType
	@return any
]=]
function ServiceBag:GetService(serviceType)
	if typeof(serviceType) == "Instance" then
		serviceType = require(serviceType)
	end

	assert(type(serviceType) == "table", "Bad serviceType definition")

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
function ServiceBag:HasService(serviceType)
	if typeof(serviceType) == "Instance" then
		serviceType = require(serviceType)
	end

	if self._services[serviceType] then
		return true
	else
		return false
	end
end

--[=[
	Initializes the service bag and ensures recursive initialization
	can occur
]=]
function ServiceBag:Init()
	assert(not self._initRunAllowed, "Already initializing")
	assert(self._serviceTypesToInitializeSet, "Already initialized")
	self._initRunAllowed = true

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
function ServiceBag:Start()
	assert(self._serviceTypesToStart, "Already started")
	assert(not self._serviceTypesToInitializeSet, "Not initialized yet. Call serviceBag:Init() first.")

	self._initRunAllowed = false

	while next(self._serviceTypesToStart) do
		local serviceType = table.remove(self._serviceTypesToStart)
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
				error(string.format("Starting service %q yielded", serviceName))
			end
		end
	end

	self._serviceTypesToStart = nil
end

function ServiceBag:_getServiceName(serviceType)
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
function ServiceBag:IsStarted()
	return self._serviceTypesToStart == nil
end

--[=[
	Creates a scoped service bag, where services within the scope will not
	be accessible outside of the scope.

	@return ServiceBag
]=]
function ServiceBag:CreateScope()
	local provider = ServiceBag.new(self)

	self:_addServiceType(provider)

	-- Remove from parent provider
	self._maid[provider] = provider._destroyingSignal:Connect(function()
		self._maid[provider] = nil
		self._services[provider] = nil
	end)

	return provider
end

-- Adds a service to this provider only
function ServiceBag:_addServiceType(serviceType)
	if self._destructing then
		local serviceName = self:_getServiceName(serviceType)
		error(string.format("Cannot query service %q after ServiceBag is cleaned up", serviceName))
		return
	end

	if self:IsStarted() then
		error(string.format("Already started, cannot add %q", self:_getServiceName(serviceType)))
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

function ServiceBag:_ensureInitialization(serviceType)
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
		self:_initService(serviceType)
	elseif self._serviceTypesToInitializeSet then
		self._serviceTypesToInitializeSet[serviceType] = true
	else
		local serviceName = self:_getServiceName(serviceType)
		error(string.format("Cannot initialize service %q after start", serviceName))
	end
end

function ServiceBag:_initService(serviceType)
	local service = assert(self._services[serviceType], "No service")
	local serviceName = self:_getServiceName(serviceType)

	if service.Init then
		local current
		task.spawn(function()
			debug.setmemorycategory(serviceName)

			local stopClock = self._serviceInitLogger:StartInitClock(serviceName)

			current = coroutine.running()
			service:Init(self)

			stopClock()
		end)

		local isDead = coroutine.status(current) == "dead"
		if not isDead then
			error(string.format("Initializing service %q yielded", serviceName))
		end
	end

	table.insert(self._serviceTypesToStart, serviceType)
end

--[=[
	Cleans up the service bag and all services that have been
	initialized in the service bag.
]=]
function ServiceBag:Destroy()
	if self._destructing then
		return
	end

	local super = getmetatable(ServiceBag)

	self._destructing = true

	self._destroyingSignal:Fire()
	self._destroyingSignal:Destroy()

	self:_destructServices()

	super.Destroy(self)
end

function ServiceBag:_destructServices()
	local services = self._services
	local serviceType, service = next(services)
	while service ~= nil do
		services[serviceType] = nil

		if not (self._serviceTypesToInitializeSet and self._serviceTypesToInitializeSet[serviceType]) then
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
				warn(string.format("Destroying service %q yielded", serviceName))
			end
		end

		serviceType, service = next(services)
	end
end

return ServiceBag