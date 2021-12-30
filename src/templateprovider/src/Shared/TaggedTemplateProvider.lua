--[=[
	Like a template provider, but it also reparents and retrieves tagged objects
	@class TaggedTemplateProvider
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TemplateProvider = require("TemplateProvider")

local TaggedTemplateProvider = setmetatable({}, TemplateProvider)
TaggedTemplateProvider.ClassName = "TaggedTemplateProvider"
TaggedTemplateProvider.__index = TaggedTemplateProvider

function TaggedTemplateProvider.new(containerTagName)
	local self = setmetatable(TemplateProvider.new(), TaggedTemplateProvider)

	assert(type(containerTagName) == "string", "Bad containerTagName")

	-- We prefer a default tag name so test scripts can still read assets for testing
	self._tagsToInitializeSet = { [containerTagName] = true }

	return self
end

function TaggedTemplateProvider:Init()
	assert(not self._maid, "Should not have a maid")

	getmetatable(TaggedTemplateProvider).Init(self)

	assert(self._maid, "Should have a maid")

	for tag, _ in pairs(self._tagsToInitializeSet) do
		self:AddContainersFromTag(tag)
	end
end

function TaggedTemplateProvider:AddContainersFromTag(containerTagName)
	assert(self._maid, "Not initialized")
	assert(type(containerTagName) == "string", "Bad containerTagName")

	if RunService:IsRunning() then
		self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(containerTagName):Connect(function(inst)
			self:AddContainer(inst)
		end))

		self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(containerTagName):Connect(function(inst)
			self:RemoveContainer(inst)
		end))
	end

	for _, inst in pairs(CollectionService:GetTagged(containerTagName)) do
		self:AddContainer(inst)
	end
end

return TaggedTemplateProvider