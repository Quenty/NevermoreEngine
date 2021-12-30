--[=[
	Legacy loading logic

	@private
	@class LegacyLoader
]=]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LoaderUtils = require(script.Parent.LoaderUtils)
local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)
local Loader = require(script.Parent.Loader)

local LegacyLoader = {}
LegacyLoader.ClassName = "LegacyLoader"
LegacyLoader.__index = LegacyLoader

function LegacyLoader.new(script)
	return setmetatable({
		_script = assert(script, "No script");
		_container = false;
		_locked = false;
		_lookupMap = {};
	}, LegacyLoader)
end

function LegacyLoader:Lock()
	assert(not self._container, "Cannot bootstrap game when legacy loader was already used")
	self._locked = true
end

function LegacyLoader:GetLoader(moduleScript)
	return Loader.new(moduleScript)
end

function LegacyLoader:Require(value)
	assert(not self._locked, "Cannot use legacy loader after already transformed")

	self:_setupIfNeeded()

	if type(value) == "number" then
		return require(value)
	elseif type(value) == "string" then
		local existing = self._lookupMap[value]
		if existing then
			return require(existing)
		else
			error("Error: Library '" .. tostring(value) .. "' does not exist.", 2)
		end
	elseif typeof(value) == "Instance" and value:IsA("ModuleScript") then
		return require(value)
	else
		error(("Error: module must be a string or ModuleScript, got '%s' for '%s'")
			:format(typeof(value), tostring(value)))
	end
end

function LegacyLoader:_buildLookupContainer()
	for _, instance in pairs(self._container:GetDescendants()) do
		if instance:IsA("ModuleScript")
			and not instance:FindFirstAncestorWhichIsA("ModuleScript") then
			local target = instance
			if BounceTemplateUtils.isBounceTemplate(instance) then
				target = BounceTemplateUtils.getTarget(instance) or instance
			end

			local existing = self._lookupMap[instance.Name]
			if existing then
				if target ~= existing then
					warn(("[LegacyLoader] - Duplicate module %q found, using first found\n\t(1) %s (used)\n\t(2) %s")
						:format(
							instance.Name,
							self._lookupMap[instance.Name]:GetFullName(),
							instance:GetFullName()))
				end
			else
				self._lookupMap[instance.Name] = target
			end
		end
	end
end

function LegacyLoader:_setupIfNeeded()
	local existingContainer = rawget(self, "_container")
	if existingContainer then
		return existingContainer
	end

	-- TODO: Handle setup by manual process
	assert(self._script.Name == "Nevermore", "Cannot invoke legacy mode if not at ReplicatedStorage.Nevermore")
	assert(self._script.Parent == ReplicatedStorage, "Cannot invoke legacy mode if not at ReplicatedStorage.Nevermore")

	if not RunService:IsRunning() then
		error("Test mode not supported")
	elseif RunService:IsServer() and RunService:IsClient() or (not RunService:IsRunning()) then
		if RunService:IsRunning() then
			error("Warning: Loading all modules in PlaySolo. It's recommended you use accurate play solo.")
		end
	elseif RunService:IsServer() then
		local container = ServerScriptService:FindFirstChild("Nevermore") or error("No ServerScriptService.Nevermore folder")
		local clientFolder, serverFolder, sharedFolder = LoaderUtils.toWallyFormat(container)

		clientFolder.Name = "_nevermoreClient"
		clientFolder.Parent = ReplicatedStorage

		sharedFolder.Name = "_nevermoreShared"
		sharedFolder.Parent = ReplicatedStorage

		serverFolder.Name = "_nevermoreServer"
		serverFolder.Parent = ServerScriptService

		rawset(self, "_container", serverFolder)
		self:_buildLookupContainer()
	elseif RunService:IsClient() then
		local container = ReplicatedStorage:WaitForChild("_nevermoreClient", 2)

		if not container then
			warn("[Nevermore] - Be sure to call require(ServerScriptService.Nevermore) on the server to replicate nevermore")
			container = ReplicatedStorage:WaitForChild("_nevermoreClient")
		end

		rawset(self, "_container", container)
		self:_buildLookupContainer()
	else
		error("Error: Unknown RunService state (Not client/server/test mode)")
	end
end

return LegacyLoader