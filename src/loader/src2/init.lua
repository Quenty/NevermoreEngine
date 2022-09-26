local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DependencyUtils = require(script.Dependencies.DependencyUtils)
local Replicator = require(script.Replication.Replicator)
local ReplicatorReferences = require(script.Replication.ReplicatorReferences)
local Maid = require(script.Maid)
local LoaderAdder = require(script.Loader.LoaderAdder)
local ReplicationType = require(script.Replication.ReplicationType)

local function handleLoad(moduleScript)
	assert(typeof(moduleScript) == "Instance", "Bad moduleScript")

	return function(request)
		if type(request) == "string" then
			local module = DependencyUtils.findDependency(moduleScript, request)
			return require(module)
		else
			return require(request)
		end
	end
end

local function bootstrapGame(packages)
	local maid = Maid.new()

	local copy = Instance.new("Folder")
	copy.Name = packages.Name
	maid:GiveTask(copy)

	local references = ReplicatorReferences.new()

	local serverAdder = LoaderAdder.new(references, packages, ReplicationType.SERVER)
	maid:GiveTask(serverAdder)

	local replicator = Replicator.new(references)
	replicator:SetTarget(copy)
	replicator:ReplicateFrom(packages)
	maid:GiveTask(replicator)

	local clientAdder = LoaderAdder.new(references, copy, ReplicationType.CLIENT)
	maid:GiveTask(clientAdder)

	copy.Parent = ReplicatedStorage

	return setmetatable({}, {__index = function(_, value)
		-- Lookup module script
		if type(value) == "string" then
			local result = DependencyUtils.findDependency(packages, value)
			if result then
				return result
			else
				error(("Could not find dependency %q"):format(value))
			end
		else
			error(("Bad index %q"):format(type(value)))
		end
	end})
end

local function bootstrapPlugin(_packages)
	error("Not implemented")
end

return {
	load = handleLoad;
	bootstrapGame = bootstrapGame;
	bootstrapPlugin = bootstrapPlugin;
}