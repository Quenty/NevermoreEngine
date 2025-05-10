--!strict
--[=[
	Utility functions involving [ReplicationType]
	@class ReplicationTypeUtils
]=]

local RunService = game:GetService("RunService")

local ReplicationType = require(script.Parent.ReplicationType)

local ReplicationTypeUtils = {}

--[=[
	Returns true if the data is a replicationType
	@param replicationType any
	@return boolean
]=]
function ReplicationTypeUtils.isReplicationType(replicationType: any): boolean
	return replicationType == ReplicationType.SHARED
		or replicationType == ReplicationType.CLIENT
		or replicationType == ReplicationType.SERVER
		or replicationType == ReplicationType.PLUGIN
end

function ReplicationTypeUtils.getFolderReplicationType(
	folderName: string,
	ancestorReplicationType: ReplicationType.ReplicationType
): ReplicationType.ReplicationType
	assert(type(folderName) == "string", "Bad folderName")
	assert(type(ancestorReplicationType) == "string", "Bad ancestorReplicationType")

	if folderName == "Shared" then
		return ReplicationType.SHARED
	elseif folderName == "Client" then
		return ReplicationType.CLIENT
	elseif folderName == "Server" then
		return ReplicationType.SERVER
	else
		return ancestorReplicationType
	end
end

function ReplicationTypeUtils.inferReplicationType(): ReplicationType.ReplicationType
	if (not RunService:IsRunning()) and RunService:IsStudio() then
		return ReplicationType.PLUGIN
	elseif RunService:IsServer() then
		return ReplicationType.SERVER
	elseif RunService:IsClient() then
		return ReplicationType.CLIENT
	else
		error("Unknown ReplicationType state")
	end
end

function ReplicationTypeUtils.isAllowed(
	replicationType: ReplicationType.ReplicationType,
	requestedReplicationType: ReplicationType.ReplicationType
): boolean
	assert(ReplicationTypeUtils.isReplicationType(replicationType), "Bad replicationType")
	assert(ReplicationTypeUtils.isReplicationType(requestedReplicationType), "Bad requestedReplicationType")

	if requestedReplicationType == ReplicationType.PLUGIN then
		return true
	elseif requestedReplicationType == ReplicationType.SHARED then
		-- NOTE: We could allow replication from shared in either direction...

		return replicationType == ReplicationType.SHARED
	elseif requestedReplicationType == ReplicationType.CLIENT then
		if replicationType == ReplicationType.SERVER then
			return false
		end

		return true
	elseif requestedReplicationType == ReplicationType.SERVER then
		if replicationType == ReplicationType.CLIENT then
			return false
		end

		return true
	else
		error("Unknown requestedReplicationType")
	end
end

return ReplicationTypeUtils
