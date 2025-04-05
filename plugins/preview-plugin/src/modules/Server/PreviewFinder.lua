--!strict
--[=[
	@class PreviewFinder
]=]

local require = require(script.Parent.loader).load(script)

local RxInstanceUtils = require("RxInstanceUtils")

local USER_SERVICES = {
	"Workspace",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPlayer",
}

local BaseObject = require("BaseObject")
local Maid = require("Maid")

local PreviewFinder = setmetatable({}, BaseObject)
PreviewFinder.ClassName = "PreviewFinder"
PreviewFinder.__index = PreviewFinder

function PreviewFinder.new(serviceBag)
	local self = setmetatable(BaseObject.new() :: any, PreviewFinder)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self:_setup()

	return self
end

function PreviewFinder:Observe()
end

function PreviewFinder:_setup()
	for _, serviceName in ipairs(USER_SERVICES) do
		local service = game:GetService(serviceName)
		self._maid:GiveTask(self:_setupParent(service))
	end
end

function PreviewFinder:_setupParent(parent)
	local maid = Maid.new()

	maid:GiveTask(parent.DescendantAdded:Connect(function(child)
		self:_handleChild(child)
	end))

	maid:GiveTask(parent.DescendantRemoving:Connect(function(child)
		self:_handleChildRemoving(child)
	end))

	for _, child in parent:GetDescendants() do
		self:_handleChild(child)
	end

	return maid
end

function PreviewFinder:_observeAll(child)
	return RxInstanceUtils.observeDescendants(child)
end

function PreviewFinder:_handleChildRemoving()
end
return PreviewFinder