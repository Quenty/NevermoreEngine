--- Utility functions for the TemplateProvider
-- @module TemplateContainerUtils
-- @author Quenty

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TemplateContainerUtils = {}

function TemplateContainerUtils.reparentFromWorkspaceIfNeeded(parent, name)
	assert(typeof(parent) == "Instance")
	assert(type(name) == "string")

	return function()
		local workspaceContainer = Workspace:FindFirstChild(name)
		local parentedContainer = parent:FindFirstChild(name)
		if workspaceContainer then
			if parentedContainer then
				error(("Duplicate container in %q and %q"):format(
					workspaceContainer:GetFullName(),
					parentedContainer:GetFullName()))
			end

			-- Reparent
			if RunService:IsRunning() then
				workspaceContainer.Parent = parent
			end

			return workspaceContainer
		end

		if not parentedContainer then
			error(("No template container with name %q in %q")
				:format(parent:GetFullName(), name))
		end

		return parentedContainer
	end
end

return TemplateContainerUtils