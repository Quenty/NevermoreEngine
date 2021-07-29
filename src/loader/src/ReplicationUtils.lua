--- Utility functions for replicating module scripts
-- @module ReplicationUtils
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationUtils = {}

local function readonly(table)
	return setmetatable(table, {
		__index = function(_, index)
			error(("Bad index %q"):format(tostring(index)), 2)
		end;
		__newindex = function(_, index, _)
			error(("Bad index %q"):format(tostring(index)), 2)
		end;
	})
end

--- Retrieves the replication scriptType for a moduleScript. Replication scriptType is based upon parent name,
--  and whether or not a given module is the first module script in the hierarchy.
function ReplicationUtils.classifyModuleScriptType(moduleScript, topParent)
	if topParent then
		local firstModuleScriptParent = moduleScript:FindFirstAncestorOfClass("ModuleScript")
		if firstModuleScriptParent and firstModuleScriptParent:IsDescendantOf(topParent) then
			return ReplicationUtils.ScriptType.SUBMODULE
		end
	end

	local parent = moduleScript.Parent
	while parent and parent ~= topParent do
		local parentName = parent.Name
		if parentName == "Server" then
			return ReplicationUtils.ScriptType.SERVER
		elseif parentName == "Client" then
			return ReplicationUtils.ScriptType.CLIENT
		end
		parent = parent.Parent
	end

	return ReplicationUtils.ScriptType.SHARED
end

function ReplicationUtils.reparentModulesOfScriptType(replicationMap, scriptType, newParent)
	assert(type(replicationMap) == "table", "Bad replicationMap")
	assert(type(scriptType) == "string", "Bad scriptType")
	assert(typeof(newParent) == "Instance", "Bad newParent")

	for _, moduleScript in pairs(replicationMap[scriptType]) do
		moduleScript.Parent = newParent
	end
end

function ReplicationUtils.getReplicationMapForScript(child, parent)
	-- This is unfortunately slow

	local replicationMap = {
		[ReplicationUtils.ScriptType.SHARED] = {};
		[ReplicationUtils.ScriptType.SERVER] = {};
		[ReplicationUtils.ScriptType.CLIENT] = {};
		[ReplicationUtils.ScriptType.SUBMODULE] = {};
	}

	local scriptType = ReplicationUtils.classifyModuleScriptType(child, parent)
	table.insert(replicationMap[scriptType], child)
	return replicationMap
end

function ReplicationUtils.getReplicationMapForParent(parent)
	assert(typeof(parent) == "Instance", "Bad parent")

	local replicationMap = {
		[ReplicationUtils.ScriptType.SHARED] = {};
		[ReplicationUtils.ScriptType.SERVER] = {};
		[ReplicationUtils.ScriptType.CLIENT] = {};
		[ReplicationUtils.ScriptType.SUBMODULE] = {};
	}

	for _, child in pairs(parent:GetDescendants()) do
		if child:IsA("ModuleScript") then
			local scriptType = ReplicationUtils.classifyModuleScriptType(child, parent)
			table.insert(replicationMap[scriptType], child)
		end
	end

	return replicationMap
end

function ReplicationUtils.mergeModuleScriptIntoLookupTable(lookupTable, moduleScript)
	if lookupTable[moduleScript.Name] then
		warn(("Warning: Duplicate name of %q already exists! Using first found!"):format(moduleScript.Name))
	else
		lookupTable[moduleScript.Name] = moduleScript
	end
end

function ReplicationUtils.mergeReplicationMapIntoLookupTable(lookupTable, replicationMap, acceptableModes)
	for _, scriptType in pairs(acceptableModes) do
		for _, moduleScript in pairs(replicationMap[scriptType]) do
			ReplicationUtils.mergeModuleScriptIntoLookupTable(lookupTable, moduleScript)
		end
	end
end

ReplicationUtils.ScriptType = readonly({
	SHARED = "shared";
	SERVER = "server";
	CLIENT = "client";
	SUBMODULE = "submodule";
})

function ReplicationUtils.isInTable(table, value)
	assert(table, "Bad table")
	assert(value, "Bad value")

	for _, item in pairs(table) do
		if item == value then
			return true
		end
	end

	return false
end

function ReplicationUtils.createReplicationFolder(name)
	assert(type(name) == "string", "Bad name")
	assert(not ReplicatedStorage:FindFirstChild(name), "Duplicate of _ReplicatedModules")

	local clientFolder = Instance.new("Folder")
	clientFolder.Name = name
	clientFolder.Parent = ReplicatedStorage

	return clientFolder
end

return ReplicationUtils