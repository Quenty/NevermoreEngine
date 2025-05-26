--[=[
	Handles searching for bound objects following links (object values) under a parent
	with a specific name.

	@class BoundLinkCollection
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Signal = require("Signal")

local BoundLinkCollection = {}
BoundLinkCollection.ClassName = "BoundLinkCollection"
BoundLinkCollection.__index = BoundLinkCollection

function BoundLinkCollection.new(binder, linkName, parent)
	local self = setmetatable({}, BoundLinkCollection)

	self._maid = Maid.new()

	self._linkName = linkName or error("No linkName")
	self._binder = binder or error("No binder")

	self.ClassAdded = self._maid:Add(Signal.new()) -- :Fire(class)
	self.ClassRemoved = self._maid:Add(Signal.new()) -- :Fire(class)

	self._classes = {} -- [class] = true
	self._canidates = {} -- [inst] = { [objValue] = true }
	self._linkCanidate = {} -- [objValue] = [inst]
	self._linkValues = {} -- [objValue] = true

	self._maid:GiveTask(self._binder:GetClassAddedSignal():Connect(function(...)
		self:_handleNewClassBound(...)
	end))
	self._maid:GiveTask(self._binder:GetClassRemovingSignal():Connect(function(class)
		self:_removeClass(class)
	end))

	self:TrackParent(parent)

	return self
end

function BoundLinkCollection:GetClasses()
	local list = {}
	for class, _ in self._classes do
		table.insert(list, class)
	end
	return list
end

function BoundLinkCollection:HasClass(class)
	return self._classes[class] ~= nil
end

function BoundLinkCollection:TrackParent(parent)
	assert(parent, "Bad parent")

	self._maid:GiveTask(parent.ChildAdded:Connect(function(child)
		if child:IsA("ObjectValue") and child.Name == self._linkName then
			self:_handleNewLink(child)
		end
	end))

	self._maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_removeLink(child)
	end))

	for _, child in parent:GetChildren() do
		if child:IsA("ObjectValue") and child.Name == self._linkName then
			self:_handleNewLink(child)
		end
	end
end

function BoundLinkCollection:_removeLink(objValue)
	self._maid[objValue] = nil
end

function BoundLinkCollection:_handleNewLink(objValue)
	local maid = Maid.new()

	maid:GiveTask(objValue.Changed:Connect(function()
		self:_handleLinkChanged(objValue)
	end))

	maid:GiveTask(function()
		self:_removeLinkCanidates(objValue)
	end)

	self._maid[objValue] = maid

	self:_handleLinkChanged(objValue)
end

function BoundLinkCollection:_handleLinkChanged(objValue)
	self:_removeLinkCanidates(objValue)

	if objValue.Value then
		self:_addCanidate(objValue, objValue.Value)
	end
end

function BoundLinkCollection:_removeLinkCanidates(objValue)
	local canidate = self._linkCanidate[objValue]
	if not canidate then
		return
	end

	self._linkCanidate[objValue] = nil

	if not self._canidates[canidate] then
		error("[BoundLinkCollection] - Got link canidate that isn''t real. This shouldn't happen.")
		return
	end

	local canidateLinks = self._canidates[canidate]
	canidateLinks[objValue] = nil

	if not next(canidateLinks) then
		self:_removeCanidate(canidate)
	end
end

function BoundLinkCollection:_removeCanidate(canidate)
	self._canidates[canidate] = nil

	local class = self._binder:Get(canidate)
	if not class then
		return
	end

	self:_removeClass(class)
end

function BoundLinkCollection:_addCanidate(objValue, canidate)
	assert(not self._linkCanidate[objValue], "Should not have existing canidate set for link")

	self._linkCanidate[objValue] = canidate

	if not self._canidates[canidate] then
		self._canidates[canidate] = {}
	end
	self._canidates[canidate][objValue] = true

	local class = self._binder:Get(canidate)
	if not class then
		return
	end
	self:_addClass(class)
end

function BoundLinkCollection:_removeClass(class)
	if not self._classes[class] then
		return
	end

	self._classes[class] = nil
	self.ClassRemoved:Fire(class)
end

function BoundLinkCollection:_addClass(class)
	if self._classes[class] then
		return
	end

	self._classes[class] = true
	self.ClassAdded:Fire(class)
end

function BoundLinkCollection:_handleNewClassBound(class, inst)
	if not self._canidates[inst] then
		return
	end

	self:_addClass(class)
end

function BoundLinkCollection:Destroy()
	self._maid:Destroy()
	setmetatable(self, nil)
end

return BoundLinkCollection
