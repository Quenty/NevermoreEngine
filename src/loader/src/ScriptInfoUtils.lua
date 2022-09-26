--[=[
	@private
	@class ScriptInfoUtils
]=]

local CollectionService = game:GetService("CollectionService")

local loader = script.Parent
local Utils = require(script.Parent.Utils)
local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)

local ScriptInfoUtils = {}

ScriptInfoUtils.DEPENDENCY_FOLDER_NAME = "node_modules";
ScriptInfoUtils.ModuleReplicationTypes = Utils.readonly({
	CLIENT = "client";
	SERVER = "server";
	SHARED = "shared";
	IGNORE = "ignore";
	PLUGIN = "plugin";
})

function ScriptInfoUtils.createScriptInfo(instance, name, replicationMode)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(name) == "string", "Bad name")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	return Utils.readonly({
		name = name;
		replicationMode = replicationMode;
		instance = instance;
	})
end

function ScriptInfoUtils.createScriptInfoLookup()
	-- Server/client also contain shared entries
	return Utils.readonly({
		[ScriptInfoUtils.ModuleReplicationTypes.SERVER] = {}; -- [string name] = scriptInfo
		[ScriptInfoUtils.ModuleReplicationTypes.CLIENT] = {};
		[ScriptInfoUtils.ModuleReplicationTypes.SHARED] = {};
		[ScriptInfoUtils.ModuleReplicationTypes.PLUGIN] = {};
	})
end

function ScriptInfoUtils.getScriptInfoLookupForMode(scriptInfoLookup, replicationMode)
	assert(type(scriptInfoLookup) == "table", "Bad scriptInfoLookup")
	assert(type(replicationMode) == "string", "Bad replicationMode")

	return scriptInfoLookup[replicationMode]
end

function ScriptInfoUtils.populateScriptInfoLookup(instance, scriptInfoLookup, lastReplicationMode)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(scriptInfoLookup) == "table", "Bad scriptInfoLookup")
	assert(type(lastReplicationMode) == "string", "Bad lastReplicationMode")

	if instance:IsA("Folder") or instance:IsA("Camera") then
		local replicationMode = ScriptInfoUtils.getFolderReplicationMode(instance.Name, lastReplicationMode)
		if replicationMode ~= ScriptInfoUtils.ModuleReplicationTypes.IGNORE then
			for _, item in pairs(instance:GetChildren()) do
				if not BounceTemplateUtils.isBounceTemplate(item) then
					if item:IsA("Folder") or item:IsA("Camera") then
						ScriptInfoUtils.populateScriptInfoLookup(item, scriptInfoLookup, replicationMode)
					elseif item:IsA("ModuleScript") then
						ScriptInfoUtils.addToInfoMap(scriptInfoLookup,
							ScriptInfoUtils.createScriptInfo(item, item.Name, replicationMode))
					end
				end
			end
		end
	elseif instance:IsA("ModuleScript") then
		if not BounceTemplateUtils.isBounceTemplate(instance) then
			if instance == loader then
				-- STRICT hack to support this module script as "loader" over "Nevermore" in replicated scenario
				ScriptInfoUtils.addToInfoMap(scriptInfoLookup,
					ScriptInfoUtils.createScriptInfo(instance, "loader", lastReplicationMode))
			else
				ScriptInfoUtils.addToInfoMap(scriptInfoLookup,
					ScriptInfoUtils.createScriptInfo(instance, instance.Name, lastReplicationMode))
			end
		end
	elseif instance:IsA("ObjectValue") then
		error("ObjectValue links are not supported at this time for retrieving inline module scripts")
	end
end

local AVAILABLE_IN_SHARED = {
	["HoldingBindersServer"] = true;
	["HoldingBindersClient"] = true;
	["IKService"] = true;
	["IKServiceClient"] = true;
}

function ScriptInfoUtils.isAvailableInShared(scriptInfo)
	if CollectionService:HasTag(scriptInfo.instance, "LinkToShared") then
		return true
	end

	-- Hack because we can't tag things in Rojo yet
	return AVAILABLE_IN_SHARED[scriptInfo.name]
end

function ScriptInfoUtils.addToInfoMap(scriptInfoLookup, scriptInfo)
	assert(type(scriptInfoLookup) == "table", "Bad scriptInfoLookup")
	assert(type(scriptInfo) == "table", "Bad scriptInfo")

	local replicationMode = assert(scriptInfo.replicationMode, "Bad replicationMode")
	local replicationMap = assert(scriptInfoLookup[replicationMode], "Bad replicationMode")

	ScriptInfoUtils.addToInfoMapForMode(replicationMap, scriptInfo)

	if replicationMode == ScriptInfoUtils.ModuleReplicationTypes.SHARED then
		ScriptInfoUtils.addToInfoMapForMode(
			scriptInfoLookup[ScriptInfoUtils.ModuleReplicationTypes.SERVER], scriptInfo)
		ScriptInfoUtils.addToInfoMapForMode(
			scriptInfoLookup[ScriptInfoUtils.ModuleReplicationTypes.CLIENT], scriptInfo)
	elseif ScriptInfoUtils.isAvailableInShared(scriptInfo) then
		ScriptInfoUtils.addToInfoMapForMode(
			scriptInfoLookup[ScriptInfoUtils.ModuleReplicationTypes.SHARED], scriptInfo)
	end
end

function ScriptInfoUtils.addToInfoMapForMode(replicationMap, scriptInfo)
	if replicationMap[scriptInfo.name] then
		warn(("Duplicate module %q in same package under same replication scope. Only using first one. \n- %q\n- %q")
			:format(scriptInfo.name,
				scriptInfo.instance:GetFullName(),
				replicationMap[scriptInfo.name].instance:GetFullName()))
		return
	end

	replicationMap[scriptInfo.name] = scriptInfo
end

function ScriptInfoUtils.getFolderReplicationMode(folderName, lastReplicationMode)
	assert(type(folderName) == "string", "Bad folderName")
	assert(type(lastReplicationMode) == "string", "Bad lastReplicationMode")

	--Plugin always replicates further
	if folderName == ScriptInfoUtils.DEPENDENCY_FOLDER_NAME then
		return ScriptInfoUtils.ModuleReplicationTypes.IGNORE
	elseif lastReplicationMode == ScriptInfoUtils.ModuleReplicationTypes.PLUGIN then
		return lastReplicationMode
	elseif folderName == "Shared" then
		return ScriptInfoUtils.ModuleReplicationTypes.SHARED
	elseif folderName == "Client" then
		return ScriptInfoUtils.ModuleReplicationTypes.CLIENT
	elseif folderName == "Server" then
		return ScriptInfoUtils.ModuleReplicationTypes.SERVER
	else
		return lastReplicationMode
	end
end

return ScriptInfoUtils