---
-- @classmod TaggedTemplateProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TemplateProvider = require("TemplateProvider")

local TaggedTemplateProvider = setmetatable({}, TemplateProvider)
TaggedTemplateProvider.ClassName = "TaggedTemplateProvider"
TaggedTemplateProvider.__index = TaggedTemplateProvider

function TaggedTemplateProvider.new(containerTagName)
	local self = setmetatable(TemplateProvider.new(), TaggedTemplateProvider)

	assert(type(containerTagName) == "string")

	-- We prefer a default tag name so test scripts can still read assets for testing
	self._tagsToInitializeSet = { [containerTagName] = true }

	return self
end

function TaggedTemplateProvider:Init()
	assert(self._tagsToInitializeSet, "Already initialized")

	getmetatable(TaggedTemplateProvider).Init(self)

	local tags = self._tagsToInitializeSet
	self._tagsToInitializeSet = nil

	for tag, _ in pairs(tags) do
		self:AddContainersFromTag(tag)
	end
end

function TaggedTemplateProvider:AddContainersFromTag(containerTagName)
	assert(type(containerTagName) == "string")

	if self._tagsToInitializeSet then
		self._tagsToInitializeSet[containerTagName] = true
	else
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
end

return TaggedTemplateProvider