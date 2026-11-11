--!strict
--[=[
	@class LoaderLinkUtils
	@private
]=]

local LoaderLink = script.Parent.LoaderLink

local LoaderLinkUtils = {}

function LoaderLinkUtils.create(loader: Instance, linkName: string): ModuleScript
	assert(typeof(loader) == "Instance", "Bad loader")
	assert(type(linkName) == "string", "Bad linkName")

	local copy = Instance.fromExisting(LoaderLink)
	copy.Name = linkName
	copy.Archivable = false

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = "LoaderLink"
	objectValue.Value = loader
	objectValue.Archivable = false
	objectValue.Parent = copy

	return copy
end

--[=[
	Whether every folder under the root that a LoaderLinkCreator would give a loader to already has one.

	@param root Instance
	@param linkName string
	@return boolean
]=]
function LoaderLinkUtils.isPopulated(root: Instance, linkName: string): boolean
	assert(typeof(root) == "Instance", "Bad root")
	assert(type(linkName) == "string", "Bad linkName")

	local function isFolderPopulated(folder: Instance, requiresLoader: boolean): boolean
		local hasLoader = false

		for _, child in folder:GetChildren() do
			if child:IsA("ModuleScript") then
				if child.Name == linkName then
					hasLoader = true
				else
					requiresLoader = true
				end
			elseif child:IsA("Folder") and not isFolderPopulated(child, false) then
				return false
			end
		end

		return hasLoader or not requiresLoader
	end

	return isFolderPopulated(root, true)
end

return LoaderLinkUtils
