--!strict
--[=[
	Tracks the closest ancestor bound to a specific binder.
	@class BoundAncestorTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local RxBinderUtils = require("RxBinderUtils")
local ValueObject = require("ValueObject")

local BoundAncestorTracker = setmetatable({}, BaseObject)
BoundAncestorTracker.ClassName = "BoundAncestorTracker"
BoundAncestorTracker.__index = BoundAncestorTracker

export type BoundAncestorTracker<T> =
	typeof(setmetatable(
		{} :: {
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

	assert(Binder.isBinder(binder), "Bad binder")
	assert(typeof(child) == "Instance", "Bad child")

	--[=[
	Bound value
	@prop Class ValueObject<T?>
	@readonly
	@within BoundAncestorTracker
]=]
	self.Class = self._maid:Add(ValueObject.new(nil :: T?))

	self._maid:GiveTask(RxBinderUtils.observeBoundAncestor(binder, child):Subscribe(function(class)
		self.Class.Value = class
	end))

	return self
end

return BoundAncestorTracker
