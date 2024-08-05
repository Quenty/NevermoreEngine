--[=[
	@class SoundGroupPathUtils
]=]

local require = require(script.Parent.loader).load(script)

local SoundService = game:GetService("SoundService")

local SoundGroupPathUtils = {}

function SoundGroupPathUtils.isSoundGroupPath(soundGroupPath)
	return type(soundGroupPath) == "string"
end

function SoundGroupPathUtils.toPathTable(soundGroupPath)
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")

	return string.split(soundGroupPath, ".")
end

function SoundGroupPathUtils.findSoundGroup(soundGroupPath, root)
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	local current = SoundService
	for _, soundGroupName in SoundGroupPathUtils.toPathTable(soundGroupPath) do
		current = SoundGroupPathUtils._findSoundGroup(current, soundGroupName)
		if not current then
			return nil
		end
	end

	return current
end

function SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath, root)
	assert(type(soundGroupPath) == "string", "Bad soundGroupPath")
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	local current = root or SoundService

	for _, soundGroupName in SoundGroupPathUtils.toPathTable(soundGroupPath) do
		local parent = current
		current = SoundGroupPathUtils._findSoundGroup(parent, soundGroupName)

		if not current then
			current = Instance.new("SoundGroup")
			current.Name = soundGroupName
			current.Volume = 1
			current.Parent = parent
		end
	end

	return current
end

function SoundGroupPathUtils._findSoundGroup(parent, soundGroupName)
	for _, item in parent:GetChildren() do
		if item:IsA("SoundGroup") and item.Name == soundGroupName then
			return item
		end
	end

	return nil
end

return SoundGroupPathUtils