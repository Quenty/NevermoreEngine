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

	local copy = LoaderLink:Clone()
	copy.Name = linkName
	copy.Archivable = false

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = "LoaderLink"
	objectValue.Value = loader
	objectValue.Parent = copy
	objectValue.Archivable = false

	return copy
end

return LoaderLinkUtils
