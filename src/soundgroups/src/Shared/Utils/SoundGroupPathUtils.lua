--!strict
--[=[
	@deprecated 1.54.0 -- Use [InstancePathUtils] from `@quenty/instance-path` instead.
	@class SoundGroupPathUtils
]=]

local require = require(script.Parent.loader).load(script)

local SoundService = game:GetService("SoundService")

local InstancePathUtils = require("InstancePathUtils")

local SoundGroupPathUtils = {}

export type InstancePath = InstancePathUtils.InstancePath
export type InstancePathTable = InstancePathUtils.InstancePathTable

local function onCreateSoundGroup(instance: Instance)
	(instance :: SoundGroup).Volume = 1
end

--[=[
	Checks if the given string is a valid sound group path.

	@deprecated 1.54.0 -- Use [InstancePathUtils.isInstancePath] instead.
	@param soundGroupPath string
	@return boolean
]=]
function SoundGroupPathUtils.isSoundGroupPath(soundGroupPath: string): boolean
	return InstancePathUtils.isInstancePath(soundGroupPath)
end

--[=[
	Converts a sound group path into a table of strings.

	@deprecated 1.54.0 -- Use [InstancePathUtils.toPathTable] instead.
	@param soundGroupPath InstancePath
	@return InstancePathTable
]=]
function SoundGroupPathUtils.toPathTable(soundGroupPath: InstancePath): InstancePathTable
	return InstancePathUtils.toPathTable(soundGroupPath)
end

--[=[
	Finds the sound group at the given path, searching from [SoundService] if no root is given.

	@deprecated 1.54.0 -- Use [InstancePathUtils.findInstance] instead.
	@param soundGroupPath InstancePath
	@param root Instance?
	@return SoundGroup?
]=]
function SoundGroupPathUtils.findSoundGroup(soundGroupPath: InstancePath, root: Instance?): SoundGroup?
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	return InstancePathUtils.findInstance(root or SoundService, soundGroupPath, "SoundGroup") :: SoundGroup?
end

--[=[
	Finds the sound group at the given path, constructing any missing sound groups along the
	way. Searches from [SoundService] if no root is given.

	@deprecated 1.54.0 -- Use [InstancePathUtils.findOrCreateInstance] instead.
	@param soundGroupPath InstancePath
	@param root Instance?
	@return SoundGroup
]=]
function SoundGroupPathUtils.findOrCreateSoundGroup(soundGroupPath: InstancePath, root: Instance?): SoundGroup
	assert(typeof(root) == "Instance" or root == nil, "Bad root")

	local parent = root or SoundService
	return InstancePathUtils.findOrCreateInstance(
			parent,
			soundGroupPath,
			"SoundGroup",
			onCreateSoundGroup
		) :: SoundGroup
end

return SoundGroupPathUtils
