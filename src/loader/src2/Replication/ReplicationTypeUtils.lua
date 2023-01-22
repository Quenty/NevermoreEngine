--[=[
	Utility functions involving [ReplicationType]
	@class ReplicationTypeUtils
]=]

local ReplicationType = require(script.Parent.ReplicationType)

local ReplicationTypeUtils = {}

--[=[
	Returns true if the data is a replicationType
	@param replicationType any
	@return boolean
]=]
function ReplicationTypeUtils.isReplicationType(replicationType)
	return replicationType == ReplicationType.SHARED
		or replicationType == ReplicationType.CLIENT
		or replicationType == ReplicationType.SERVER
end

function ReplicationTypeUtils.getFolderReplicationType(folderName, ancestorReplicationType)
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


return ReplicationTypeUtils