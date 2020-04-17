---
-- @classmod ApplyTagToTaggedChildren

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CollectionService = game:GetService("CollectionService")

local BaseObject = require("BaseObject")

local ApplyTagToTaggedChildren = setmetatable({}, BaseObject)
ApplyTagToTaggedChildren.ClassName = "ApplyTagToTaggedChildren"
ApplyTagToTaggedChildren.__index = ApplyTagToTaggedChildren

function ApplyTagToTaggedChildren.new(parent, tag, requiredTag)
	local self = setmetatable(BaseObject.new(), ApplyTagToTaggedChildren)

	self._parent = parent or error("No parent")
	self._requiredTag = requiredTag or error("No requiredTag")
	self._tag = tag or error("No tag")

	assert(self._requiredTag ~= self._tag)

	self._tagged = {}

	self._maid:GiveTask(function()
		for tagged, _ in pairs(self._tagged) do
			CollectionService:RemoveTag(tagged, self._tag)
		end
	end)

	self:_setup()


	return self
end

function ApplyTagToTaggedChildren:_setup()
	self._maid:GiveTask(self._parent.ChildAdded:Connect(function(...)
		self:_handleChildAdded(...)
	end))
	self._maid:GiveTask(self._parent.ChildRemoved:Connect(function(...)
		self:_removeTagIfTagged(...)
	end))

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._requiredTag)
		:Connect(function(...)
			self:_handleRequiredTagAddedToAnyInstance(...)
		end))

	self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._requiredTag)
		:Connect(function(...)
			self:_removeTagIfTagged(...)
		end))

	for _, child in pairs(self._parent:GetChildren()) do
		self:_handleChildAdded(child)
	end
end

function ApplyTagToTaggedChildren:_handleRequiredTagAddedToAnyInstance(child)
	if child.Parent == self._parent then
		self._tagged[child] = true
		CollectionService:AddTag(child, self._tag)
	end
end

function ApplyTagToTaggedChildren:_handleChildAdded(child)
	if CollectionService:HasTag(child, self._requiredTag) then
		self._tagged[child] = true
		CollectionService:AddTag(child, self._tag)
	end
end

function ApplyTagToTaggedChildren:_removeTagIfTagged(child)
	if self._tagged[child] then
		self._tagged[child] = nil
		CollectionService:RemoveTag(child, self._tag)
	end
end

return ApplyTagToTaggedChildren