--[=[
	Adds the loader instance so script.Parent.loader works.
	@class LoaderAdder
]=]

local loader = script.Parent.Parent
local BounceTemplateUtils = require(script.Parent.Parent.Bounce.BounceTemplateUtils)
local ReplicatorReferences = require(script.Parent.Parent.Replication.ReplicatorReferences)
local Maid = require(script.Parent.Parent.Maid)
local ReplicationType = require(script.Parent.Parent.Replication.ReplicationType)
local ReplicationTypeUtils = require(script.Parent.Parent.Replication.ReplicationTypeUtils)

local LoaderAdder = {}
LoaderAdder.ClassName = "LoaderAdder"
LoaderAdder.__index = LoaderAdder

function LoaderAdder.new(references, root, replicationType)
	local self = setmetatable({}, LoaderAdder)

	assert(typeof(root) == "Instance", "Bad root")
	assert(ReplicatorReferences.isReplicatorReferences(references), "Bad references")
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")

	self._references = references
	self._root = root
	self._replicationType = replicationType

	self._maid = Maid.new()

	self._needsLoaderCount = Instance.new("IntValue")
	self._needsLoaderCount.Value = 0
	self._maid:GiveTask(self._needsLoaderCount)

	self._hasLoaderCount = Instance.new("IntValue")
	self._hasLoaderCount.Value = 0
	self._maid:GiveTask(self._hasLoaderCount)

	self._needsLoader = Instance.new("BoolValue")
	self._needsLoader.Value = false
	self._maid:GiveTask(self._needsLoader)

	self._maid:GiveTask(self._needsLoaderCount.Changed:Connect(function()
		self:_updateNeedsLoader()
	end))
	self._maid:GiveTask(self._hasLoaderCount.Changed:Connect(function()
		self:_updateNeedsLoader()
	end))

	self._maid:GiveTask(self._needsLoader.Changed:Connect(function()
		if self._needsLoader.Value then
			self._maid._loader = self:_renderLoader()
		else
			self._maid._loader = nil
		end
	end))

	self:_updateNeedsLoader()

	if self._replicationType ~= ReplicationType.SERVER then
		self._maid:GiveTask(self._references:ObserveReferenceChanged(loader, function(value)
			if value and value ~= loader then
				self._maid._trackFakeLoader = self:_trackLoaderReference(value)
			else
				self._maid._trackFakeLoader = nil
			end
		end))
	end
	self._maid:GiveTask(self:_trackLoaderReference(loader))

	-- Do actual setup
	self._maid:GiveTask(root.ChildAdded:Connect(function(child)
		self:_handleChildAdded(child)
	end))
	self._maid:GiveTask(root.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(child)
	end))
	for _, child in pairs(root:GetChildren()) do
		self:_handleChildAdded(child)
	end

	return self
end

function LoaderAdder:_updateNeedsLoader()
	self._needsLoader.Value = (self._needsLoaderCount.Value > 0) and self._hasLoaderCount.Value <= 0
end

function LoaderAdder:_handleChildRemoved(child)
	self._maid[child] = nil
end

function LoaderAdder:_handleChildAdded(child)
	assert(typeof(child) == "Instance", "Bad child")

	local maid = Maid.new()


	if child:IsA("ModuleScript") then
		self:_setupNeedsLoaderCountAdd(maid, 1)
	else
		-- TODO: Maybe add to children with node_modules explicitly in its list.
		local loaderAdder = LoaderAdder.new(self._references, child, self._replicationType)
		maid:GiveTask(loaderAdder)
	end

	self._maid[child] = maid
end

function LoaderAdder:_renderLoader()
	local maid = Maid.new()

	if self._replicationType == ReplicationType.SERVER then
		maid._current = self:_doLoaderRender(loader)
	else
		maid:GiveTask(self._references:ObserveReferenceChanged(loader, function(value)
			if value then
				maid._current = self:_doLoaderRender(value)
			else
				maid._current = nil
			end
		end))
	end

	return maid
end

function LoaderAdder:_doLoaderRender(value)
	local loaderLink = BounceTemplateUtils.create(value, loader.Name)
	loaderLink.Parent = self._root

	return loaderLink
end

function LoaderAdder:_setupNeedsLoaderCountAdd(maid, amount)
	assert(Maid.isMaid(maid), "Bad maid")
	assert(type(amount) == "number", "Bad amount")

	self._needsLoaderCount.Value = self._needsLoaderCount.Value + amount
	maid:GiveTask(function()
		self._needsLoaderCount.Value = self._needsLoaderCount.Value - amount
	end)
end

function LoaderAdder:_addToLoaderCount(amount)
	assert(type(amount) == "number", "Bad amount")

	self._hasLoaderCount.Value = self._hasLoaderCount.Value + amount
	return function()
		self._hasLoaderCount.Value = self._hasLoaderCount.Value - amount
	end
end

function LoaderAdder:_trackLoaderReference(ref)
	local maid = Maid.new()

	-- TODO: Maybe handle loader reparenting more elegantly? this seems deeply unlikely.
	if ref.Parent == self._root then
		maid._current = self:_addToLoaderCount(1)
	end

	maid:GiveTask(ref:GetPropertyChangedSignal("Parent"):Connect(function()
		if ref.Parent == self._root then
			maid._current = self:_addToLoaderCount(1)
		else
			maid._current = nil
		end
	end))

	return maid
end

--[=[
	Cleans up the replicator disconnecting all events and cleaning up
	created instances.
]=]
function LoaderAdder:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return LoaderAdder