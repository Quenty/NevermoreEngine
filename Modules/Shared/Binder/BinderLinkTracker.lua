--- Handles searching for bound objects following links (object values) under a parent
-- with a specific name.
-- @classmod BinderLinkTracker
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local Signal = require("Signal")

local BinderLinkTracker = {}
BinderLinkTracker.ClassName = "BinderLinkTracker"
BinderLinkTracker.__index = BinderLinkTracker

function BinderLinkTracker.new(binder, linkName, parent)
	local self = setmetatable({}, BinderLinkTracker)

	self._maid = Maid.new()

	self._linkName = linkName or error("No linkName")
	self._binder = binder or error("No binder")

	self.ClassAdded = Signal.new() -- :Fire(class)
	self.ClassRemoved = Signal.new() -- :Fire(class)

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

function BinderLinkTracker:HasClass(class)
	return self._classes[class]
end

function BinderLinkTracker:GetClasses()
	local list = {}
	for class, _ in pairs(self._classes) do
		table.insert(list, class)
	end
	return list
end

function BinderLinkTracker:HasClass(class)
	return self._classes[class] ~= nil
end

function BinderLinkTracker:TrackParent(parent)
	assert(parent)

	self._maid:GiveTask(parent.ChildAdded:Connect(function(child)
		if child:IsA("ObjectValue") and child.Name == self._linkName then
			self:_handleNewLink(child)
		end
	end))

	self._maid:GiveTask(parent.ChildRemoved:Connect(function(child)
		self:_removeLink(child)
	end))

	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == self._linkName then
			self:_handleNewLink(child)
		end
	end
end

function BinderLinkTracker:_removeLink(objValue)
	self._maid[objValue] = nil
end

function BinderLinkTracker:_handleNewLink(objValue)
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

function BinderLinkTracker:_handleLinkChanged(objValue)
	self:_removeLinkCanidates(objValue)

	if objValue.Value then
		self:_addCanidate(objValue, objValue.Value)
	end
end

function BinderLinkTracker:_removeLinkCanidates(objValue)
	local canidate = self._linkCanidate[objValue]
	if not canidate then
		return
	end

	self._linkCanidate[objValue] = nil

	if not self._canidates[canidate] then
		error("[BinderLinkTracker] - Got link canidate that isn''t real. This shouldn't happen.")
		return
	end

	local canidateLinks = self._canidates[canidate]
	canidateLinks[objValue] = nil

	if not next(canidateLinks) then
		self:_removeCanidate(canidate)
	end
end

function BinderLinkTracker:_removeCanidate(canidate)
	self._canidates[canidate] = nil

	local class = self._binder:Get(canidate)
	if not class then
		return
	end

	self:_removeClass(class)
end

function BinderLinkTracker:_addCanidate(objValue, canidate)
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

function BinderLinkTracker:_removeClass(class)
	if not self._classes[class] then
		return
	end

	self._classes[class] = nil
	self.ClassRemoved:Fire(class)
end

function BinderLinkTracker:_addClass(class)
	if self._classes[class] then
		return
	end

	self._classes[class] = true
	self.ClassAdded:Fire(class)
end

function BinderLinkTracker:_handleNewClassBound(class, inst)
	if not self._canidates[inst] then
		return
	end

	self:_addClass(class)
end

function BinderLinkTracker:Destroy()
	self._maid:Destroy()
	setmetatable(self, nil)
end

return BinderLinkTracker
