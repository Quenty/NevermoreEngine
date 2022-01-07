--[=[
	@private
	@class LoaderConstants
]=]

local Utils = require(script.Parent.Utils)

return Utils.readonly({
	GROUP_EACH_PACKAGE_INDIVIDUALLY = false;
	ALLOW_MULTIPLE_GROUPS = true;
	INCLUDE_IMPLICIT_DEPENDENCIES = true;
})