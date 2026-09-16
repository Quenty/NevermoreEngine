--!strict
--[=[
	Tracks the parent bound to a specific binder.
	@class BoundParentTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local RxBinderUtils = require("RxBinderUtils")
local ValueObject = require("ValueObject")

local BoundParentTracker = setmetatable({}, BaseObject)
BoundParentTracker.ClassName = "BoundParentTracker"
BoundParentTracker.__index = BoundParentTracker

export type BoundParentTracker<T> =
	typeof(setmetatable(
		{} :: {
			Class: ValueObject.ValueObject<T?>,
		},
		{} :: typeof({ __index = BoundParentTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new BoundParentTracker

	@param binder Binder<T>
	@param child Instance
	@return BoundParentTracker
]=]
function BoundParentTracker.new<T>(binder: Binder.Binder<T>, child: Instance): BoundParentTracker<T>
	local self: BoundParentTracker<T> = setmetatable(BaseObject.new() :: any, BoundParentTracker)

	assert(Binder.isBinder(binder), "Bad binder")
	assert(typeof(child) == "Instance", "Bad child")

	--[=[
	Bound value
	@prop Class ValueObject<T?>
	@readonly
	@within BoundParentTracker
]=]
	self.Class = self._maid:Add(ValueObject.new(nil :: T?))

	self._maid:GiveTask(RxBinderUtils.observeBoundParent(binder, child):Subscribe(function(class)
		self.Class.Value = class
	end))

	return self
end

return BoundParentTracker
