--!strict
--[=[
	@class RbxAssetUtils
]=]

local RbxAssetUtils = {}

export type RbxAssetIdConvertable = string | number

--[=[
	Converts a string or number to a string for playback.
	@param id string | number
	@return string?
]=]
function RbxAssetUtils.toRbxAssetId(id: RbxAssetIdConvertable): string
	if type(id) == "number" then
		return string.format("rbxassetid://%d", id)
	else
		return id
	end
end

--[=[
	Returns if it's convertable to a RBXAssetId
	@param id string | number
	@return boolean
]=]
function RbxAssetUtils.isConvertableToRbxAsset(id: any): boolean
	return type(id) == "string" or type(id) == "number"
end

return RbxAssetUtils
