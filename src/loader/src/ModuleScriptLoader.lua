--- Class that lets you load in modules and replicate them properly
-- @classmod ModuleScriptLoader
-- @author Quenty

local ModuleScriptUtils = require(script.Parent:WaitForChild("ModuleScriptUtils"))
local ReplicationUtils = require(script.Parent:WaitForChild("ReplicationUtils"))

local ModuleScriptLoader = {}

function ModuleScriptLoader.new(loadableModes, scriptTypeParentMap)
	local self = setmetatable({}, ModuleScriptLoader)

	self._loadableScriptTypes = loadableModes or {
		-- Default to loading everything but ReplicationUtils.ScriptType.SUBMODULE
		ReplicationUtils.ScriptType.SHARED;
		ReplicationUtils.ScriptType.SERVER;
		ReplicationUtils.ScriptType.CLIENT;
	}
	self._scriptTypeReplicationParentMap = scriptTypeParentMap or {}

	self._lookupTable = {}
	self._require = ModuleScriptUtils.requireByName(ModuleScriptUtils.detectCyclicalRequires(require), self._lookupTable)

	return self
end

function ModuleScriptLoader:AddModule(moduleScript)
	assert(typeof(moduleScript) == "Instance" and moduleScript:IsA("ModuleScript"), "Bad moduleScript")

	local scriptType = ReplicationUtils.classifyModuleScriptType(moduleScript, nil)
	local actionTaken = false

	-- Load if possible
	if ReplicationUtils.isInTable(self._loadableScriptTypes, scriptType) then
		ReplicationUtils.mergeModuleScriptIntoLookupTable(self._lookupTable, moduleScript)
		actionTaken = true
	end

	-- Reparent
	if self._scriptTypeReplicationParentMap[scriptType] then
		moduleScript.Parent = self._scriptTypeReplicationParentMap[scriptType]
		actionTaken = true
	end

	if not actionTaken then
		warn(("Warning: Added module %q but it was not replicated or added to lookup table")
			:format(moduleScript:GetFullName()))
	end
end

function ModuleScriptLoader:AddModulesFromParent(parent)
	assert(typeof(parent) == "Instance", "Modules must be added from parent")

	do
		local replicationMap = ReplicationUtils.getReplicationMapForParent(parent)

		-- Merge into lookup table
		ReplicationUtils.mergeReplicationMapIntoLookupTable(self._lookupTable, replicationMap, self._loadableScriptTypes)

		-- Do replication
		for scriptType, replicationParent in pairs(self._scriptTypeReplicationParentMap) do
			ReplicationUtils.reparentModulesOfScriptType(replicationMap, scriptType, replicationParent)
		end
	end

	-- Observe lookup
	local conn = parent.DescendantAdded:Connect(function(child)
		if not child:IsA("ModuleScript") then
			return
		end

		-- This is slow, unfortunately
		local replicationMap = ReplicationUtils.getReplicationMapForScript(child, parent)
		ReplicationUtils.mergeReplicationMapIntoLookupTable(self._lookupTable, replicationMap, self._loadableScriptTypes)

		for scriptType, replicationParent in pairs(self._scriptTypeReplicationParentMap) do
			ReplicationUtils.reparentModulesOfScriptType(replicationMap, scriptType, replicationParent)
		end
	end)

	-- Cleanup function
	return function()
		conn:Disconnect()
		-- TODO: Remove added items too
	end
end

function ModuleScriptLoader:__call(...)
	return self._require(...)
end

function ModuleScriptLoader:__index(index)
	if ModuleScriptLoader[index] then
		return ModuleScriptLoader[index]
	end

	return self._require(index)
end

return ModuleScriptLoader