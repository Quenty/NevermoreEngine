--!strict
--[=[
	Adds the loader instance so script.Parent.loader works.

	@class LoaderLinkCreator
]=]

local loader = script.Parent.Parent
local LoaderLinkUtils = require(loader.LoaderLink.LoaderLinkUtils)
local LoaderScheduler = require(loader.Timing.LoaderScheduler)
local LoaderValueObject = require(loader.Helpers.LoaderValueObject)
local Maid = require(loader.Maid)
local ReplicatorReferences = require(loader.Replication.ReplicatorReferences)

local LoaderLinkCreator = {}
LoaderLinkCreator.ClassName = "LoaderLinkCreator"
LoaderLinkCreator.__index = LoaderLinkCreator

export type LoaderLinkCreator = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_root: Instance,
		_references: ReplicatorReferences.ReplicatorReferences?,
		_scheduler: LoaderScheduler.LoaderScheduler,
		_hasLoaderCount: LoaderValueObject.LoaderValueObject<number>,
		_childRequiresLoaderCount: LoaderValueObject.LoaderValueObject<number>,
		_provideLoader: LoaderValueObject.LoaderValueObject<boolean>,
		_lastProvidedLoader: Instance?,
	},
	{} :: typeof({ __index = LoaderLinkCreator })
))

function LoaderLinkCreator.new(
	root: Instance,
	references: ReplicatorReferences.ReplicatorReferences?,
	isRoot: boolean?,
	scheduler: LoaderScheduler.LoaderScheduler
): LoaderLinkCreator
	assert(typeof(root) == "Instance", "Bad root")
	assert(ReplicatorReferences.isReplicatorReferences(references) or references == nil, "Bad references")
	assert(LoaderScheduler.isLoaderScheduler(scheduler), "Bad scheduler")

	local self = setmetatable({}, LoaderLinkCreator)
	self._maid = Maid.new()

	self._root = root
	self._references = references
	self._scheduler = scheduler

	self._childRequiresLoaderCount = self._maid:Add(LoaderValueObject.new(isRoot and 1 or 0))
	self._hasLoaderCount = self._maid:Add(LoaderValueObject.new(0))
	self._provideLoader = self._maid:Add(LoaderValueObject.new(false))

	return self :: LoaderLinkCreator
end

--[=[
	Renders the loader links for this root. Split out of the constructor so
	the caller controls when the (potentially yielding) render pass happens.
]=]
function LoaderLinkCreator.RenderAsync(self: LoaderLinkCreator)
	self._scheduler:YieldIfNeededAsync()

	-- Our root may have been removed while we were yielded, which destroys us
	if not self.Destroy then
		return
	end

	self:_setupEventTrackingAsync()
	self:_setupRendering()
end

function LoaderLinkCreator._setupEventTrackingAsync(self: LoaderLinkCreator)
	self._maid:GiveTask(self._root.ChildAdded:Connect(function(child)
		local loaderLinkCreator = self:_handleChildAdded(child)
		if loaderLinkCreator then
			loaderLinkCreator:RenderAsync()
		end
	end))
	self._maid:GiveTask(self._root.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(child)
	end))

	for _, child in self._root:GetChildren() do
		local loaderLinkCreator = self:_handleChildAdded(child)
		if loaderLinkCreator then
			loaderLinkCreator:RenderAsync()

			if not self.Destroy then
				return
			end
		end
	end

	if not self.Destroy then
		return
	end

	-- Need to do this AFTER child added loop
	if self._references then
		self._maid:GiveTask(self._references:ObserveReferenceChanged(loader, function(replicatedLoader: Instance?)
			if replicatedLoader and replicatedLoader ~= loader then
				self._maid._trackFakeLoader = (self :: any):_countLoaderReferences(replicatedLoader)
			else
				self._maid._trackFakeLoader = nil
			end
		end))
	else
		self._maid:GiveTask((self :: any):_countLoaderReferences(loader))
	end

	-- Update state
	self._maid:GiveTask(self._childRequiresLoaderCount.Changed:Connect(function()
		self:_updateProviderLoader()
	end))
	self._maid:GiveTask(self._hasLoaderCount.Changed:Connect(function()
		self:_updateProviderLoader()
	end))
	self:_updateProviderLoader()
end

function LoaderLinkCreator._setupRendering(self: LoaderLinkCreator)
	if self._references then
		local function renderLoader()
			if self._provideLoader.Value then
				self._maid._loader = self:_renderLoaderWithReferences(self._references)
			else
				self._maid._loader = nil
			end
		end

		self._maid:GiveTask(self._provideLoader.Changed:Connect(renderLoader))
		renderLoader()
	else
		local function renderLoader()
			if self._provideLoader.Value then
				self._maid._loader = self:_doLoaderRender(loader)
			else
				self._maid._loader = nil
			end
		end

		-- No references, just render as needed
		self._maid:GiveTask(self._provideLoader.Changed:Connect(renderLoader))
		renderLoader()
	end
end

function LoaderLinkCreator._updateProviderLoader(self: LoaderLinkCreator)
	self._provideLoader.Value = (self._childRequiresLoaderCount.Value > 0) and self._hasLoaderCount.Value <= 0
end

function LoaderLinkCreator._handleChildRemoved(self: LoaderLinkCreator, child: Instance)
	self._maid[child] = nil
end

function LoaderLinkCreator._handleChildAdded(self: LoaderLinkCreator, child: Instance): LoaderLinkCreator?
	assert(typeof(child) == "Instance", "Bad child")

	if child:IsA("ModuleScript") then
		if child.Name == "loader" then
			if child ~= self._lastProvidedLoader then
				self._maid[child] = self:_addToHasLoaderCount(1)
			end
		else
			self._maid[child] = self:_incrementNeededLoader(1)
		end
	elseif child:IsA("Folder") then
		-- TODO: Maybe add to children with node_modules explicitly in its list.
		local linkCreator = LoaderLinkCreator.new(child, self._references, false, self._scheduler)
		self._maid[child] = linkCreator

		return linkCreator
	end

	return nil
end

function LoaderLinkCreator._renderLoaderWithReferences(
	self: LoaderLinkCreator,
	references: ReplicatorReferences.ReplicatorReferences
): Maid.Maid
	local maid = Maid.new()

	maid:GiveTask(references:ObserveReferenceChanged(loader, function(value: Instance?)
		if value then
			maid._current = self:_doLoaderRender(value)
		else
			maid._current = nil
		end
	end))

	return maid
end

function LoaderLinkCreator._doLoaderRender(self: LoaderLinkCreator, value: Instance)
	local loaderLink = LoaderLinkUtils.create(value, loader.Name)
	self._lastProvidedLoader = loaderLink

	loaderLink.Parent = self._root

	return loaderLink
end

function LoaderLinkCreator._incrementNeededLoader(self: LoaderLinkCreator, amount: number): () -> ()
	assert(type(amount) == "number", "Bad amount")

	self._childRequiresLoaderCount.Value = self._childRequiresLoaderCount.Value + amount
	return function()
		if self._childRequiresLoaderCount.Destroy then
			self._childRequiresLoaderCount.Value = self._childRequiresLoaderCount.Value - amount
		end
	end
end

function LoaderLinkCreator._addToHasLoaderCount(self: LoaderLinkCreator, amount: number): () -> ()
	assert(type(amount) == "number", "Bad amount")

	self._hasLoaderCount.Value = self._hasLoaderCount.Value + amount
	return function()
		if self._hasLoaderCount.Destroy then
			self._hasLoaderCount.Value = self._hasLoaderCount.Value - amount
		end
	end
end

function LoaderLinkCreator._countLoaderReferences(self: LoaderLinkCreator, robloxInst: Instance): Maid.Maid
	assert(typeof(robloxInst) == "Instance", "Bad robloxInst")

	local maid = Maid.new()

	-- TODO: Maybe handle loader reparenting more elegantly? this seems deeply unlikely.
	if robloxInst.Parent == self._root then
		maid._current = self:_addToHasLoaderCount(1)
	end

	maid:GiveTask(robloxInst:GetPropertyChangedSignal("Parent"):Connect(function()
		if robloxInst.Parent == self._root then
			maid._current = self:_addToHasLoaderCount(1)
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
function LoaderLinkCreator.Destroy(self: LoaderLinkCreator)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return LoaderLinkCreator
