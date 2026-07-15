--!strict
--[=[
	Tracks a parent bound to a specific binder
	@class BoundParentTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local ValueObject = require("ValueObject")

local BoundParentTracker = setmetatable({}, BaseObject)
BoundParentTracker.ClassName = "BoundParentTracker"
BoundParentTracker.__index = BoundParentTracker

export type BoundParentTracker<T> =
	typeof(setmetatable(
		{} :: {
			_child: Instance,
			_binder: Binder.Binder<T>,
			Class: ValueObject.ValueObject<T?>,
		},
		{} :: typeof({ __index = BoundParentTracker })
	))
	& BaseObject.BaseObject

function BoundParentTracker.new<T>(binder: Binder.Binder<T>, child: Instance): BoundParentTracker<T>
	local self: BoundParentTracker<T> = setmetatable(BaseObject.new() :: any, BoundParentTracker)

	self._child = child or error("No child")
	self._binder = binder or error("No binder")

	-- Bound value
	self.Class = ValueObject.new(nil :: T?)
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

function BoundParentTracker._update<T>(self: BoundParentTracker<T>): ()
	local parent = self._child.Parent
	if not parent then
		self.Class.Value = nil
		return
	end

	self.Class.Value = self._binder:Get(parent)
end

return BoundParentTracker
