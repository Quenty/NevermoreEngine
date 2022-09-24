--[=[
	@class ReplicationUtils
]=]

local ReplicationUtils = {}

function ReplicationUtils.replicateToClient(source)
	if source:IsA("Folder") then
		local result = Instance.new("Folder")
		result.Name = source.Name

		for child in ReplicationUtils.replicateChildren(source) do
			child.Parent = result
		end

		return result
	elseif source:IsA("ModuleScript") then
		-- want to reparent this to client.
	end
end

function ReplicationUtils.replicateChildren(source)
	return coroutine.wrap(function()
		for _, child in pairs(source:Clone()) do
			local copy = ReplicationUtils.replicateToClient(child)
			coroutine.yield(copy)
		end
	end)
end

return ReplicationUtils