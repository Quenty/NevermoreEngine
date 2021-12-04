---
-- @classmod ServiceBag
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local BaseObject = require("BaseObject")

local ServiceBag = setmetatable({}, BaseObject)
ServiceBag.ClassName = "ServiceBag"
ServiceBag.__index = ServiceBag

-- parentProvider is optional
function ServiceBag.new(parentProvider)
	local self = setmetatable(BaseObject.new(), ServiceBag)

	self._services = {}
	self._parentProvider = parentProvider

	self._serviceTypesToInitializeSet = {}
	self._initializedServiceTypeSet = {}
	self._initializing = false

	self._serviceTypesToStart = {}

	self._destroying = Signal.new()
	self._maid:GiveTask(self._destroying)

	return self
end

function ServiceBag.isServiceBag(serviceBag)
	return type(serviceBag) == "table"
		and serviceBag.ClassName == "ServiceBag"
end

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

function ServiceBag:HasService(serviceType)
	if self._services[serviceType] then
		return true
	else
		return false
	end
end

function ServiceBag:Init()
	assert(not self._initializing, "Already initializing")
	assert(self._serviceTypesToInitializeSet, "Already initialized")
	self._initializing = true

	while next(self._serviceTypesToInitializeSet) do
		local serviceType = next(self._serviceTypesToInitializeSet)
		self._serviceTypesToInitializeSet[serviceType] = nil

		self:_ensureInitialization(serviceType)
	end

	self._serviceTypesToInitializeSet = nil
	self._initializing = false
end

function ServiceBag:Start()
	assert(self._serviceTypesToStart, "Already started")
	assert(not self._initializing, "Still initializing")

	while next(self._serviceTypesToStart) do
		local serviceType = table.remove(self._serviceTypesToStart)
		local service = assert(self._services[serviceType], "No service")
		if service.Start then
			service:Start()
		end
	end

	self._serviceTypesToStart = nil
end

function ServiceBag:CreateScope()
	local provider = ServiceBag.new(self)

	self:_addServiceType(provider)

	-- Remove from parent provider
	self._maid[provider] = provider._destroying:Connect(function()
		self._maid[provider] = nil
		self._services[provider] = nil
	end)

	return provider
end

--- Adds a service to this provider only
function ServiceBag:_addServiceType(serviceType)
	if not self._serviceTypesToInitializeSet then
		error(("Already finished initializing, cannot add %q"):format(tostring(serviceType)))
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

	if self._initializing then
		self._serviceTypesToInitializeSet[serviceType] = nil
		self._initializedServiceTypeSet[serviceType] = true
		self:_initService(serviceType)
	elseif self._serviceTypesToInitializeSet then
		self._serviceTypesToInitializeSet[serviceType] = true
	else
		error("[ServiceBag._ensureInitialization] - Cannot initialize past initializing phase ")
	end
end

function ServiceBag:_initService(serviceType)
	local service = assert(self._services[serviceType], "No service")

	if service.Init then
		service:Init(self)
	end

	table.insert(self._serviceTypesToStart, serviceType)
end


function ServiceBag:Destroy()
	local super = getmetatable(ServiceBag)

	self._destroying:Fire()

	local services = self._services
	local key, service = next(services)
	while service ~= nil do
		services[key] = nil
		if service.Destroy then
			service:Destroy()
		end
		key, service = next(services)
	end

	super.Destroy(self)
end

return ServiceBag