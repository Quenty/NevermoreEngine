--!strict
--[=[
	Class that while constructed apply a tag to any children of the parent it is given, assuming that
	class has the required tag.

	This lets you bridge tag systems since CollectionService is used as an interop model between many
	components in scripts.

	@class ApplyTagToTaggedChildren
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local BaseObject = require("BaseObject")

local ApplyTagToTaggedChildren = setmetatable({}, BaseObject)
ApplyTagToTaggedChildren.ClassName = "ApplyTagToTaggedChildren"
ApplyTagToTaggedChildren.__index = ApplyTagToTaggedChildren

export type ApplyTagToTaggedChildren = typeof(setmetatable(
	{} :: {
		_parent: Instance,
		_tagged: { [Instance]: boolean },
		_tag: string,
		_requiredTag: string,
	},
	{} :: typeof({ __index = ApplyTagToTaggedChildren })
)) & BaseObject.BaseObject

--[=[
	Creates a new ApplyTagToTaggedChildren.
	@param parent Instance
	@param tag string
	@param requiredTag string
	@return ApplyTagToTaggedChildren
]=]
function ApplyTagToTaggedChildren.new(parent: Instance, tag: string, requiredTag: string): ApplyTagToTaggedChildren
	local self: ApplyTagToTaggedChildren = setmetatable(BaseObject.new() :: any, ApplyTagToTaggedChildren)

	self._parent = parent or error("No parent")
	self._requiredTag = requiredTag or error("No requiredTag")
	self._tag = tag or error("No tag")

	assert(self._requiredTag ~= self._tag, "Bad requiredTag")

	self._tagged = {}

	self._maid:GiveTask(function()
		for tagged, _ in self._tagged do
			CollectionService:RemoveTag(tagged, self._tag)
		end
	end)

	self:_setup()

	return self
end

function ApplyTagToTaggedChildren._setup(self: ApplyTagToTaggedChildren)
	self._maid:GiveTask(self._parent.ChildAdded:Connect(function(...)
		self:_handleChildAdded(...)
	end))
	self._maid:GiveTask(self._parent.ChildRemoved:Connect(function(...)
		self:_removeTagIfTagged(...)
	end))

	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(self._requiredTag):Connect(function(...)
		self:_handleRequiredTagAddedToAnyInstance(...)
	end))

	self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(self._requiredTag):Connect(function(...)
		self:_removeTagIfTagged(...)
	end))

	for _, child in self._parent:GetChildren() do
		self:_handleChildAdded(child)
	end
end

function ApplyTagToTaggedChildren._handleRequiredTagAddedToAnyInstance(self: ApplyTagToTaggedChildren, child: Instance)
	if child.Parent == self._parent then
		self._tagged[child] = true
		CollectionService:AddTag(child, self._tag)
	end
end

function ApplyTagToTaggedChildren._handleChildAdded(self: ApplyTagToTaggedChildren, child: Instance)
	if CollectionService:HasTag(child, self._requiredTag) then
		self._tagged[child] = true
		CollectionService:AddTag(child, self._tag)
	end
end

function ApplyTagToTaggedChildren._removeTagIfTagged(self: ApplyTagToTaggedChildren, child: Instance)
	if self._tagged[child] then
		self._tagged[child] = nil
		CollectionService:RemoveTag(child, self._tag)
	end
end

return ApplyTagToTaggedChildren
