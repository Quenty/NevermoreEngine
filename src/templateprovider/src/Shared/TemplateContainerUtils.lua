--[=[
	Utility functions for the TemplateProvider
	@class TemplateContainerUtils
]=]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TemplateContainerUtils = {}

function TemplateContainerUtils.reparentFromWorkspaceIfNeeded(parent, name)
	assert(typeof(parent) == "Instance", "Bad parent")
	assert(type(name) == "string", "Bad name")

	local workspaceContainer = Workspace:FindFirstChild(name)
	local parentedContainer = parent:FindFirstChild(name)
	if workspaceContainer then
		if parentedContainer then
			error(string.format("Duplicate container in %q and %q",
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
		error(string.format("No template container with name %q in %q", parent:GetFullName(), name))
	end

	return parentedContainer
end

return TemplateContainerUtils