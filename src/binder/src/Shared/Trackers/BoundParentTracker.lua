--[=[
	Tracks a parent bound to a specific binder
	@class BoundParentTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")

local BoundParentTracker = setmetatable({}, BaseObject)
BoundParentTracker.ClassName = "BoundParentTracker"
BoundParentTracker.__index = BoundParentTracker

function BoundParentTracker.new(binder, child)
	local self = setmetatable(BaseObject.new(), BoundParentTracker)

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
	self._maid:GiveTask(self._child:GetPropertyChangedSignal("Parent"):Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

function BoundParentTracker:_update()
	local parent = self._child.Parent
	if not parent then
		self.Class.Value = nil
		return
	end

	self.Class.Value = self._binder:Get(parent)
end

return BoundParentTracker
