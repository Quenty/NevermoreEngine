--!strict
--[=[
	Tracks a parent bound to a specific binder
	@class BoundAncestorTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local BinderUtils = require("BinderUtils")
local ValueObject = require("ValueObject")

local BoundAncestorTracker = setmetatable({}, BaseObject)
BoundAncestorTracker.ClassName = "BoundAncestorTracker"
BoundAncestorTracker.__index = BoundAncestorTracker

export type BoundAncestorTracker<T> =
	typeof(setmetatable(
		{} :: {
			_child: Instance,
			_binder: Binder.Binder<T>,
			Class: ValueObject.ValueObject<T?>,
		},
		{} :: typeof({ __index = BoundAncestorTracker })
	))
	& BaseObject.BaseObject

--[=[
Constructs a new BoundAncestorTracker

@param binder Binder<T>
@param child Instance
@return BoundAncestorTracker
]=]
function BoundAncestorTracker.new<T>(binder: Binder.Binder<T>, child: Instance): BoundAncestorTracker<T>
	local self: BoundAncestorTracker<T> = setmetatable(BaseObject.new() :: any, BoundAncestorTracker)

	self._child = child or error("No child")
	self._binder = binder or error("No binder")

	--[=[
	@prop Class ValueObject<T>
	@readonly
	@within BoundAncestorTracker
	Bound value
]=]
	self.Class = ValueObject.new() :: ValueObject.ValueObject<T?>
	self._maid:GiveTask(self.Class)

	-- Handle instance removing
	self._maid:GiveTask(self._binder:GetClassRemovingSignal():Connect(function(class)
		if class == self.Class.Value then
			self.Class.Value = nil
		end
	end))

	self._maid:GiveTask(self._binder:GetClassAddedSignal():Connect(function(_, instance)
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

function BoundAncestorTracker._update<T>(self: BoundAncestorTracker<T>): ()
	local parent = self._child.Parent
	if not parent then
		self.Class.Value = nil
		return
	end

	self.Class.Value = BinderUtils.findFirstAncestor(self._binder, parent)
end

return BoundAncestorTracker
