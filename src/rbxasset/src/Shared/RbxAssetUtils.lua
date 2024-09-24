--[=[
	@class RbxAssetUtils
]=]

local require = require(script.Parent.loader).load(script)

local RbxAssetUtils = {}

--[=[
	Converts a string or number to a string for playback.
	@param id string? | number
	@return string?
]=]
function RbxAssetUtils.toRbxAssetId(id: string? | number): string
	if type(id) == "number" then
		return string.format("rbxassetid://%d", id)
	else
		return id
	end
end

function RbxAssetUtils.isConvertableToRbxAsset(id: any): boolean
	return type(id) == "string" or type(id) == "number"
end

return RbxAssetUtils