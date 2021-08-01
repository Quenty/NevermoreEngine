---
-- @classmod ServiceBag
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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

	self._servicesToInitialize = {}
	self._initializing = false

	self._servicesToStart = {}

	self._destroying = Signal.new()
	self._maid:GiveTask(self._destroying)

	return self
end

function ServiceBag.isServiceBag(serviceBag)
	return type(serviceBag) == "table"
		and serviceBag.ClassName == "ServiceBag"
end

function ServiceBag:GetService(serviceType)
	if self._services[serviceType] then
		-- Ensure initialized if we're during inint phase
		if self._servicesToInitialize and self._initializing then
			local index = table.find(self._servicesToInitialize, serviceType)
			if index then
				local service = assert(table.remove(self._servicesToInitialize, index), "No service removed")
				self:_initService(service)
			end
		end

		return self._services[serviceType]
	end

	if self._parentProvider then
		return self._parentProvider:GetService(serviceType)
	end

	-- Try to add the service if we're still initializing services
	self:_addService(serviceType)
	return self._services[serviceType]
end

function ServiceBag:Init()
	assert(not self._initializing, "Already initializing")
	assert(self._servicesToInitialize, "Already initialized")
	self._initializing = true

	while next(self._servicesToInitialize) do
		local service = table.remove(self._servicesToInitialize)
		self:_initService(service)
	end

	self._servicesToInitialize = nil
	self._initializing = false
end

function ServiceBag:Start()
	assert(self._servicesToStart, "Already started")
	assert(not self._initializing, "Still initializing")

	while next(self._servicesToStart) do
		local service = table.remove(self._servicesToStart)
		if service.Start then
			service:Start()
		end
	end

	self._servicesToStart = nil
end

--- Adds a service to this provider only
function ServiceBag:_addService(service)
	assert(self._servicesToInitialize, "Already finished initializing, cannot add more services")

	-- Already added
	if self._services[service] then
		return
	end

	self._services[service] = service

	if self._initializing then
		-- let's initialize immediately
		self:_initService(service)
	else
		table.insert(self._servicesToInitialize, service)
	end
end

function ServiceBag:_initService(service)
	if service.Init then
		service:Init(self)
	end

	table.insert(self._servicesToStart, service)
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