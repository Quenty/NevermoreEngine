--- Tracks child of type
-- @classmod BoundChildCollection

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local BoundChildCollection = setmetatable({}, BaseObject)
BoundChildCollection.ClassName = "BoundChildCollection"
BoundChildCollection.__index = BoundChildCollection

function BoundChildCollection.new(binder, parent)
	local self = setmetatable(BaseObject.new(), BoundChildCollection)

	self._binder = binder or error("No binder")
	self._parent = parent or error("No parent")

	--- Fires on class addition
	self.ClassAdded = Signal.new() -- :Fire(class)
	self._maid:GiveTask(self.ClassAdded)

	--- Fires on class removal
	self.ClassRemoved = Signal.new() -- :Fire(class)
	self._maid:GiveTask(self.ClassRemoved)

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

--- Returns whether the track has the class
-- @return true if the class exists, nil otherwise
function BoundChildCollection:HasClass(class)
	return self._classes[class]
end

function BoundChildCollection:GetSize()
	return self._size
end

--- Returns the raw classes variable as [class] = true
-- @return The set
function BoundChildCollection:GetSet()
	return self._classes
end

--- Slow than :GetSet(), but adds them in an ordered list
-- @return The list
function BoundChildCollection:GetClasses()
	local list = {}
	for class, _ in pairs(self._classes) do
		table.insert(list, class)
	end
	return list
end

function BoundChildCollection:_startTracking()
	self._maid:GiveTask(self._parent.ChildAdded:Connect(function(child)
		self:_addChild(child)
	end))

	self._maid:GiveTask(self._parent.ChildRemoved:Connect(function(child)
		self:_removeChild(child)
	end))

	for _, child in pairs(self._parent:GetChildren()) do
		-- Specifically do not fire on init because nothing is listening
		self:_addChild(child, true)
	end
end

function BoundChildCollection:_addChild(inst, doNotFire)
	local class = self._binder:Get(inst)
	if not class then
		return
	end

	self:_addClass(class, doNotFire)
end

function BoundChildCollection:_handleNewClassBound(class, inst)
	if inst.Parent ~= self._parent then
		return
	end

	self:_addClass(class)
end

function BoundChildCollection:_removeChild(inst)
	local class = self._binder:Get(inst)
	if not class then
		return
	end

	self:_removeClass(class)
end

function BoundChildCollection:_addClass(class, doNotFire)
	if self._classes[class] then
		return
	end

	self._classes[class] = true
	self._size = self._size + 1
	if not doNotFire then
		self.ClassAdded:Fire(class)
	end
end

function BoundChildCollection:_removeClass(class)
	if not self._classes[class] then
		return
	end

	self._classes[class] = nil
	self._size = self._size - 1
	self.ClassRemoved:Fire(class)
end

return BoundChildCollection