--- Base of a template retrieval system
-- @classmod TemplateProvider

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local String = require("String")

local TemplateProvider = setmetatable({}, BaseObject)
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

-- @param[opt=nil] container
function TemplateProvider.new(container)
	local self = setmetatable(BaseObject.new(), TemplateProvider)

	self._containersToInitializeSet = { }

	if container then
		self:AddContainer(container)
	end

	self._registry = {} -- [name] = rawTemplate
	self._containersSet = {} -- [parent] = true

	return self
end

-- Initializes the container provider
function TemplateProvider:Init()
	assert(self._containersToInitializeSet, "Already initialized")

	local containers = self._containersToInitializeSet
	self._containersToInitializeSet = nil

	for container, _ in pairs(containers) do
		self:AddContainer(container)
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
	assert(typeof(container) == "Instance")

	if self._containersToInitializeSet then
		self._containersToInitializeSet[container] = true
	else
		assert(not self._containersSet[container], "Already added")

		self._containersSet[container] = true
		self._maid[container] = self:_loadFolder(container)
	end
end

function TemplateProvider:RemoveContainer(container)
	if self._containersToInitializeSet then
		self._containersToInitializeSet[container] = nil
	else
		self._containersSet[container] = nil
		self._maid[container] = nil
	end
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
	if not self._containersToInitializeSet then
		return
	end

	if (not RunService:IsRunning()) then
		-- Initialize for hoarcecat!
		self:Init()
	end

	assert(not self._containersToInitializeSet, "TemplateProvider is not initialized")
end

function TemplateProvider:_transformParent(getParent)
	if typeof(getParent) == "Instance" then
		return getParent
	elseif type(getParent) == "function" then
		local container = getParent()
		assert(typeof(container) == "Instance")
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

return TemplateProvider