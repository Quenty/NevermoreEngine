--!strict
--[=[
	Handles searching for bound objects following links (object values) under a parent
	with a specific name.

	@class BoundLinkCollection
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Maid = require("Maid")
local Signal = require("Signal")

local BoundLinkCollection = {}
BoundLinkCollection.ClassName = "BoundLinkCollection"
BoundLinkCollection.__index = BoundLinkCollection

export type BoundLinkCollection = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_linkName: string,
		_binder: Binder.Binder<any>,
		ClassAdded: Signal.Signal<any>,
		ClassRemoved: Signal.Signal<any>,
		_classes: { [any]: boolean },
		_canidates: { [Instance]: { [Instance]: boolean } },
		_linkCanidate: { [Instance]: Instance },
		_linkValues: { [Instance]: boolean },
	},
	{} :: typeof({ __index = BoundLinkCollection })
))

function BoundLinkCollection.new(binder: Binder.Binder<any>, linkName: string, parent: Instance): BoundLinkCollection
	local self: BoundLinkCollection = setmetatable({} :: any, BoundLinkCollection)

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

function BoundLinkCollection.GetClasses(self: BoundLinkCollection): { any }
	local list = {}
	for class, _ in self._classes do
		table.insert(list, class)
	end
	return list
end

function BoundLinkCollection.HasClass(self: BoundLinkCollection, class: any): boolean
	return self._classes[class] ~= nil
end

function BoundLinkCollection.TrackParent(self: BoundLinkCollection, parent: Instance): ()
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

function BoundLinkCollection._removeLink(self: BoundLinkCollection, objValue: Instance): ()
	self._maid[objValue] = nil
end

function BoundLinkCollection._handleNewLink(self: BoundLinkCollection, objValue: ObjectValue): ()
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

function BoundLinkCollection._handleLinkChanged(self: BoundLinkCollection, objValue: ObjectValue): ()
	self:_removeLinkCanidates(objValue)

	if objValue.Value then
		self:_addCanidate(objValue, objValue.Value)
	end
end

function BoundLinkCollection._removeLinkCanidates(self: BoundLinkCollection, objValue: Instance): ()
	local canidate = self._linkCanidate[objValue]
	if not canidate then
		return
	end

	self._linkCanidate[objValue] = nil

	if not self._canidates[canidate] then
		error("[BoundLinkCollection] - Got link canidate that isn''t real. This shouldn't happen.")
	end

	local canidateLinks = self._canidates[canidate]
	canidateLinks[objValue] = nil

	if not next(canidateLinks) then
		self:_removeCanidate(canidate)
	end
end

function BoundLinkCollection._removeCanidate(self: BoundLinkCollection, canidate: Instance): ()
	self._canidates[canidate] = nil

	local class = self._binder:Get(canidate)
	if not class then
		return
	end

	self:_removeClass(class)
end

function BoundLinkCollection._addCanidate(self: BoundLinkCollection, objValue: Instance, canidate: Instance): ()
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

function BoundLinkCollection._removeClass(self: BoundLinkCollection, class: any): ()
	if not self._classes[class] then
		return
	end

	self._classes[class] = nil
	self.ClassRemoved:Fire(class)
end

function BoundLinkCollection._addClass(self: BoundLinkCollection, class: any): ()
	if self._classes[class] then
		return
	end

	self._classes[class] = true
	self.ClassAdded:Fire(class)
end

function BoundLinkCollection._handleNewClassBound(self: BoundLinkCollection, class: any, inst: Instance): ()
	if not self._canidates[inst] then
		return
	end

	self:_addClass(class)
end

function BoundLinkCollection.Destroy(self: BoundLinkCollection): ()
	self._maid:Destroy()
	setmetatable(self :: any, nil)
end

return BoundLinkCollection
