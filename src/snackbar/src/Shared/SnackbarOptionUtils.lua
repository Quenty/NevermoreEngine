--[=[
	@class SnackbarOptionUtils

]=]

local require = require(script.Parent.loader).load(script)

local t = require("t")

local SnackbarOptionUtils = {}

function SnackbarOptionUtils.createSnackbarOptions(options)
	assert(SnackbarOptionUtils.isSnackbarOptions(options))

	return options
end

SnackbarOptionUtils.isSnackbarOptions = t.interface({
	CallToAction = t.optional(t.union(t.string, t.interface({
		Text = t.string;
		OnClick = t.optional(t.callback);
	})));
})

return SnackbarOptionUtils