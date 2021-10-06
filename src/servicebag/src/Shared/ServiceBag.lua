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

	self._serviceTypesToInitialize = {}
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

	local service = self._services[serviceType]
	if service then
		-- Ensure initialized if we're during init phase
		if self._serviceTypesToInitialize and self._initializing then
			local index = table.find(self._serviceTypesToInitialize, service)
			if index then
				local foundServiceType = assert(table.remove(self._serviceTypesToInitialize, index), "No service removed")
				assert(foundServiceType == service, "foundServiceType ~= service")
				self:_initService(foundServiceType)
			end
		end

		return self._services[serviceType]
	end

	if self._parentProvider then
		return self._parentProvider:GetService(serviceType)
	end

	-- Try to add the service if we're still initializing services
	self:_addServiceType(serviceType)
	return self._services[serviceType]
end

function ServiceBag:Init()
	assert(not self._initializing, "Already initializing")
	assert(self._serviceTypesToInitialize, "Already initialized")
	self._initializing = true

	while next(self._serviceTypesToInitialize) do
		local serviceType = table.remove(self._serviceTypesToInitialize)
		self:_initService(serviceType)
	end

	self._serviceTypesToInitialize = nil
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

--- Adds a service to this provider only
function ServiceBag:_addServiceType(serviceType)
	assert(self._serviceTypesToInitialize, "Already finished initializing, cannot add more services")

	-- Already added
	if self._services[serviceType] then
		return
	end

	-- Construct a new version of this service so we're isolated
	local service = setmetatable({}, { __index = serviceType })
	self._services[serviceType] = service

	if self._initializing then
		-- let's initialize immediately
		self:_initService(serviceType)
	else
		table.insert(self._serviceTypesToInitialize, serviceType)
	end
end

function ServiceBag:_initService(serviceType)
	local service = assert(self._services[serviceType], "No service")

	if service.Init then
		service:Init(self)
	end

	table.insert(self._serviceTypesToStart, serviceType)
end

function ServiceBag:CreateScope()
	local provider = ServiceBag.new(self)

	self._services[provider] = provider

	-- Remove from parent provider
	self._maid[provider] = provider._destroying:Connect(function()
		self._maid[provider] = nil
		self._services[provider] = nil
	end)

	return provider
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