--!strict
--[=[
	Tracks child of type of a binder.
	@class BoundChildCollection
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local Set = require("Set")
local Signal = require("Signal")

local BoundChildCollection = setmetatable({}, BaseObject)
BoundChildCollection.ClassName = "BoundChildCollection"
BoundChildCollection.__index = BoundChildCollection

export type BoundChildCollection<T> = typeof(setmetatable(
	{} :: {
		_binder: Binder.Binder<T>,
		_parent: Instance,
		_classes: Set.Set<T>,
		ClassAdded: Signal.Signal<T>,
		ClassRemoved: Signal.Signal<T>,
		_size: number,
	},
	{} :: typeof({ __index = BoundChildCollection })
)) & BaseObject.BaseObject

--[=[
	Constructcs a new BoundChildCollection.
	@param binder Binder<T>
	@param parent Instance
	@return BoundChildCollection<T>
]=]
function BoundChildCollection.new<T>(binder: Binder.Binder<T>, parent: Instance): BoundChildCollection<T>
	local self: BoundChildCollection<T> = setmetatable(BaseObject.new() :: any, BoundChildCollection)

	self._binder = binder or error("No binder")
	self._parent = parent or error("No parent")

	--[=[
	Fires on class addition
	@prop ClassAdded Signal<T>
	@within BoundChildCollection
]=]
	self.ClassAdded = self._maid:Add(Signal.new() :: any) -- :Fire(class)

	--[=[
	Fires on class removal
	@prop ClassRemoved Signal<T>
	@within BoundChildCollection
]=]
	self.ClassRemoved = self._maid:Add(Signal.new() :: any) -- :Fire(class)

	self._classes = {} -- [class] = true
	self._size = 0

	self._maid:GiveTask(self._binder:GetClassAddedSignal():Connect(function(...)
		self:_handleNewClassBound(...)
	end))
	self._maid:GiveTask(self._binder:GetClassRemovingSignal():Connect(function(class)
		self:_removeClass(class)
	end))

	self:_startTracking()

	return self
end

--[=[
	Returns whether the track has the class
	@param class T
	@return boolean? -- true if the class exists, nil otherwise
]=]
function BoundChildCollection.HasClass<T>(self: BoundChildCollection<T>, class: T): boolean
	return self._classes[class]
end

--[=[
	Gets the size
	@return number
]=]
function BoundChildCollection.GetSize<T>(self: BoundChildCollection<T>): number
	return self._size
end

--[=[
	Returns the raw classes variable as [class] = true.

	:::warning
	Do not modify the set
	:::

	@return { [T] = true } -- The set
]=]
function BoundChildCollection.GetSet<T>(self: BoundChildCollection<T>): Set.Set<T>
	return self._classes
end

--[=[
	Slow than :GetSet(), but adds them in an ordered list
	@return { T }
]=]
function BoundChildCollection.GetClasses<T>(self: BoundChildCollection<T>): { T }
	local list = {}
	for class, _ in self._classes do
		table.insert(list, class)
	end
	return list
end

function BoundChildCollection._startTracking<T>(self: BoundChildCollection<T>)
	self._maid:GiveTask(self._parent.ChildAdded:Connect(function(child)
		self:_addChild(child)
	end))

	self._maid:GiveTask(self._parent.ChildRemoved:Connect(function(child)
		self:_removeChild(child)
	end))

	for _, child in self._parent:GetChildren() do
		-- Specifically do not fire on init because nothing is listening
		self:_addChild(child, true)
	end
end

function BoundChildCollection._addChild<T>(self: BoundChildCollection<T>, inst: Instance, doNotFire: boolean?): ()
	local class = self._binder:Get(inst)
	if not class then
		return
	end

	self:_addClass(class, doNotFire)
end

function BoundChildCollection._handleNewClassBound<T>(self: BoundChildCollection<T>, class: T, inst: Instance): ()
	if inst.Parent ~= self._parent then
		return
	end

	self:_addClass(class)
end

function BoundChildCollection._removeChild<T>(self: BoundChildCollection<T>, inst: Instance): ()
	local class = self._binder:Get(inst)
	if not class then
		return
	end

	self:_removeClass(class)
end

function BoundChildCollection._addClass<T>(self: BoundChildCollection<T>, class: T, doNotFire: boolean?): ()
	if self._classes[class] then
		return
	end

	self._classes[class] = true
	self._size = self._size + 1
	if not doNotFire then
		self.ClassAdded:Fire(class)
	end
end

function BoundChildCollection._removeClass<T>(self: BoundChildCollection<T>, class: T): ()
	if not self._classes[class] then
		return
	end

	self._classes[class] = nil
	self._size = self._size - 1
	self.ClassRemoved:Fire(class)
end

return BoundChildCollection
