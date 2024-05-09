--[=[
	@class SnackbarScreenGuiProvider
]=]

local require = require(script.Parent.loader).load(script)

local GenericScreenGuiProvider = require("GenericScreenGuiProvider")

return GenericScreenGuiProvider.new({
	SNACKBAR = 0;
})