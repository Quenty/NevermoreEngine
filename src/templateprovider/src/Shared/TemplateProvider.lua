--- Base of a template retrieval system
-- @classmod TemplateProvider

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local String = require("String")

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

-- @param[opt=nil] container
function TemplateProvider.new(container)
	local self = setmetatable({}, TemplateProvider)

	if container then
		self._containersToInitializeSet = { [container] = true }
	end

	return self
end

-- Initializes the container provider
function TemplateProvider:Init()
	assert(not self._initialized, "Already initialized")

	self._maid = Maid.new()
	self._initialized = true
	self._registry = {} -- [name] = rawTemplate
	self._containersSet = {} -- [parent] = true

	if self._containersToInitializeSet then
		for container, _ in pairs(self._containersToInitializeSet) do
			self:AddContainer(container)
		end
	end
end

-- Clones the template. If it has a prefix of "Template" then it will remove it
function TemplateProvider:Clone(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	self:_verifyInit()

	local template = self._registry[templateName]
	if not template then
		error(("[TemplateProvider.Clone] - Cannot provide %q"):format(tostring(templateName)))
		return nil
	end

	local newItem = template:Clone()
	newItem.Name = String.removePostfix(templateName, "Template")
	return newItem
end

-- Returns the raw template
function TemplateProvider:Get(templateName)
	assert(type(templateName) == "string", "templateName must be a string")
	self:_verifyInit()

	return self._registry[templateName]
end

-- Adds a new container to the provider for provision of assets
function TemplateProvider:AddContainer(container)
	assert(typeof(container) == "Instance", "Bad container")
	assert(not self._containersSet[container], "Already added")
	self:_verifyInit()

	self._containersSet[container] = true
	self._maid[container] = self:_loadFolder(container)
end

function TemplateProvider:RemoveContainer(container)
	assert(typeof(container) == "Instance", "Bad container")
	self:_verifyInit()

	self._containersSet[container] = nil
	self._maid[container] = nil
end

-- Returns whether or not a template is registered at the time
function TemplateProvider:IsAvailable(templateName)
	assert(type(templateName) == "string", "templateName must be a string")
	self:_verifyInit()

	return self._registry[templateName] ~= nil
end

-- Returns all current registered items
function TemplateProvider:GetAll()
	self:_verifyInit()

	local list = {}
	for _, item in pairs(self._registry) do
		table.insert(list, item)
	end

	return list
end

-- Gets the container
function TemplateProvider:GetContainers()
	self:_verifyInit()

	local list = {}
	for parent, _ in pairs(self._containersSet) do
		table.insert(list, parent)
	end
	return list
end

function TemplateProvider:_verifyInit()
	if not RunService:IsRunning() then
		-- Initialize for hoarcecat!
		self:Init()
	end

	assert(self._initialized, "TemplateProvider is not initialized")
end

function TemplateProvider:_transformParent(getParent)
	if typeof(getParent) == "Instance" then
		return getParent
	elseif type(getParent) == "function" then
		local container = getParent()
		assert(typeof(container) == "Instance", "Bad container")
		return container
	else
		error("Bad getParent type")
	end
end

function TemplateProvider:_loadFolder(parent)
	local maid = Maid.new()

	-- Only connect events if we're running
	if RunService:IsRunning() then
		maid:GiveTask(parent.ChildAdded:Connect(function(child)
			self:_handleChildAdded(maid, child)
		end))
		maid:GiveTask(parent.ChildRemoved:Connect(function(child)
			self:_handleChildRemoved(maid, child)
		end))
	end

	for _, child in pairs(parent:GetChildren()) do
		self:_handleChildAdded(maid, child)
	end

	maid:GiveTask(function()
		maid:DoCleaning()

		-- Deregister children
		for _, child in pairs(parent:GetChildren()) do
			self:_handleChildRemoved(maid, child)
		end
	end)

	return maid
end

function TemplateProvider:_handleChildRemoved(maid, child)
	maid[child] = nil
	self:_removeFromRegistry(child)
end

function TemplateProvider:_handleChildAdded(maid, child)
	if child:IsA("Folder") then
		maid[child] = self:_loadFolder(child)
	else
		self:_addToRegistery(child)
	end
end

function TemplateProvider:_addToRegistery(child)
	local childName = child.Name
	if self._registry[childName] then
		warn(("[TemplateProvider._addToRegistery] - Duplicate %q in registery. Overridding")
			:format(childName))
	end

	self._registry[childName] = child
end

function TemplateProvider:_removeFromRegistry(child)
	local childName = child.Name

	if self._registry[childName] == child then
		self._registry[childName] = nil
	end
end

function TemplateProvider:Destroy()
	self._maid:DoCleaning()
end

return TemplateProvider