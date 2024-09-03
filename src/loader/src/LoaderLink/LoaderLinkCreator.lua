--[=[
	Adds the loader instance so script.Parent.loader works.

	@class LoaderLinkCreator
]=]

local loader = script.Parent.Parent
local LoaderLinkUtils = require(loader.LoaderLink.LoaderLinkUtils)
local ReplicatorReferences = require(loader.Replication.ReplicatorReferences)
local Maid = require(loader.Maid)

local LoaderLinkCreator = {}
LoaderLinkCreator.ClassName = "LoaderLinkCreator"
LoaderLinkCreator.__index = LoaderLinkCreator

function LoaderLinkCreator.new(root, references, isRoot)
	assert(typeof(root) == "Instance", "Bad root")
	assert(ReplicatorReferences.isReplicatorReferences(references) or references == nil, "Bad references")

	local self = setmetatable({}, LoaderLinkCreator)
	self._maid = Maid.new()

	self._root = root
	self._references = references

	self._childRequiresLoaderCount = self._maid:Add(Instance.new("IntValue"))
	self._childRequiresLoaderCount.Value = isRoot and 1 or 0

	self._hasLoaderCount = self._maid:Add(Instance.new("IntValue"))
	self._hasLoaderCount.Value = 0

	self._provideLoader = self._maid:Add(Instance.new("BoolValue"))
	self._provideLoader.Value = false

	-- prevent frame delay
	self:_setupEventTracking()
	self:_setupRendering()

	return self
end

function LoaderLinkCreator:_setupEventTracking()
	self._maid:GiveTask(self._root.ChildAdded:Connect(function(child)
		self:_handleChildAdded(child)
	end))
	self._maid:GiveTask(self._root.ChildRemoved:Connect(function(child)
		self:_handleChildRemoved(child)
	end))

	for _, child in pairs(self._root:GetChildren()) do
		self:_handleChildAdded(child)
	end

	-- Need to do this AFTER child added loop
	if self._references then
		self._maid:GiveTask(self._references:ObserveReferenceChanged(loader, function(replicatedLoader)
			if replicatedLoader and replicatedLoader ~= loader then
				self._maid._trackFakeLoader = self:_countLoaderReferences(replicatedLoader)
			else
				self._maid._trackFakeLoader = nil
			end
		end))
	else
		self._maid:GiveTask(self:_countLoaderReferences(loader))
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

function LoaderLinkCreator:_setupRendering()
	if self._references then
		local function renderLoader()
			if self._provideLoader.Value then
				self._maid._loader = self:_renderLoaderWithReferences()
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

function LoaderLinkCreator:_updateProviderLoader()
	self._provideLoader.Value = (self._childRequiresLoaderCount.Value > 0) and self._hasLoaderCount.Value <= 0
end

function LoaderLinkCreator:_handleChildRemoved(child)
	self._maid[child] = nil
end

function LoaderLinkCreator:_handleChildAdded(child)
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
		self._maid[child] = LoaderLinkCreator.new(child, self._references)
	end
end

function LoaderLinkCreator:_renderLoaderWithReferences()
	local maid = Maid.new()

	maid:GiveTask(self._references:ObserveReferenceChanged(loader, function(value)
		if value then
			maid._current = self:_doLoaderRender(value)
		else
			maid._current = nil
		end
	end))

	return maid
end

function LoaderLinkCreator:_doLoaderRender(value)
	local loaderLink = LoaderLinkUtils.create(value, loader.Name)
	self._lastProvidedLoader = loaderLink

	loaderLink.Parent = self._root


	return loaderLink
end

function LoaderLinkCreator:_incrementNeededLoader(amount)
	assert(type(amount) == "number", "Bad amount")

	self._childRequiresLoaderCount.Value = self._childRequiresLoaderCount.Value + amount
	return function()
		self._childRequiresLoaderCount.Value = self._childRequiresLoaderCount.Value - amount
	end
end

function LoaderLinkCreator:_addToHasLoaderCount(amount)
	assert(type(amount) == "number", "Bad amount")

	self._hasLoaderCount.Value = self._hasLoaderCount.Value + amount
	return function()
		self._hasLoaderCount.Value = self._hasLoaderCount.Value - amount
	end
end

function LoaderLinkCreator:_countLoaderReferences(robloxInst)
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
function LoaderLinkCreator:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return LoaderLinkCreator