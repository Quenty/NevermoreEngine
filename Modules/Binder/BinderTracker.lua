--- Tracks a parent bound to a specific binder
-- @classmod BinderTracker
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")

local BinderTracker = setmetatable({}, BaseObject)
BinderTracker.ClassName = "BinderTracker"
BinderTracker.__index = BinderTracker

function BinderTracker.new(binder, child)
	local self = setmetatable(BaseObject.new(), BinderTracker)

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

	-- Perform update
	self._maid:GiveTask(self._child.AncestryChanged:Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

function BinderTracker:_update()
	local parent = self._child.Parent
	if not parent then
		self.Class.Value = nil
		return
	end

	self.Class.Value = self._binder:Get(parent)
end

return BinderTracker