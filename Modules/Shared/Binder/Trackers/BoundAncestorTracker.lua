--- Tracks a parent bound to a specific binder
-- @classmod BoundAncestorTracker

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local BinderUtil = require("BinderUtil")

local BoundAncestorTracker = setmetatable({}, BaseObject)
BoundAncestorTracker.ClassName = "BoundAncestorTracker"
BoundAncestorTracker.__index = BoundAncestorTracker

function BoundAncestorTracker.new(binder, child)
	local self = setmetatable(BaseObject.new(), BoundAncestorTracker)

	self._child = child or error("No child")
	self._binder = binder or error("No binder")

	-- Bound value
	self.Class = ValueObject.new()
	self._maid:GiveTask(self.Class)

	-- Handle instance removing
	self._maid:GiveTask(self._binder:GetClassRemovingSignal():Connect(function(class)
		if class == self.Class.Value then
			self.Class.Value = nil
		end
	end))

	self._maid:GiveTask(self._binder:GetClassAddedSignal():Connect(function(class, instance)
		if self._child:IsDescendantOf(instance) then
			self:_update()
		end
	end))

	-- Perform update
	self._maid:GiveTask(self._child.AncestryChanged:Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

function BoundAncestorTracker:_update()
	local parent = self._child.Parent
	if not parent then
		self.Class.Value = nil
		return
	end

	self.Class.Value = BinderUtil.findFirstAncestor(self._binder, parent)
end

return BoundAncestorTracker