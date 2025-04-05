--!strict
--[=[
	@class SoundGroupPathUtils
]=]

local SoundService = game:GetService("SoundService")

local SoundGroupPathUtils = {}

--[=[
	Checks if the given string is a valid sound group path.

	@param soundGroupPath string
	@return boolean
]=]
function SoundGroupPathUtils.isSoundGroupPath(soundGroupPath: string): boolean
	return type(soundGroupPath) == "string"
end

--[=[
	Converts a sound group path into a table of strings.

	@param soundGroupPath string
	@return { string }
]=]
function SoundGroupPathUtils.toPathTable(soundGroupPath: string): { string }
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")

	return string.split(soundGroupPath, ".")
end

--[=[
	Converts a table of strings into a sound group path.

	@param soundGroupPath string
	@param root Instance?
	@return SoundGroup
]=]
function SoundGroupPathUtils.findSoundGroup(soundGroupPath: string, root: Instance?): SoundGroup?
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	local current: Instance = root or SoundService
	for _, soundGroupName in SoundGroupPathUtils.toPathTable(soundGroupPath) do
		local found = SoundGroupPathUtils._findSoundGroup(current, soundGroupName)
		if not found then
			return nil
		end
		current = found
	end

	if current ~= root and current:IsA("SoundGroup") then
		return current
	else
		return nil
	end
end

--[=[
	Converts a table of strings into a sound group path.

	@param soundGroupPath string
	@return SoundGroup
]=]
function SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath: string, root: Instance?): SoundGroup
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	local current: Instance = root or SoundService

	for _, soundGroupName in SoundGroupPathUtils.toPathTable(soundGroupPath) do
		local parent = current
		local found = SoundGroupPathUtils._findSoundGroup(parent, soundGroupName)

		if found then
			current = found
		else
			local constructed = Instance.new("SoundGroup")
			constructed.Name = soundGroupName
			constructed.Volume = 1
			constructed.Parent = parent
			current = constructed
		end
	end

	assert(current:IsA("SoundGroup"), "Current is not a SoundGroup")
	return current
end

function SoundGroupPathUtils._findSoundGroup(parent: Instance, soundGroupName: string): SoundGroup?
	for _, item in parent:GetChildren() do
		if item:IsA("SoundGroup") and item.Name == soundGroupName then
			return item
		end
	end

	return nil
end

return SoundGroupPathUtils