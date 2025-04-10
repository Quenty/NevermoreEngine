--!strict
--[=[
	@class SnackbarOptionUtils
]=]

local require = require(script.Parent.loader).load(script)

local t = require("t")

local SnackbarOptionUtils = {}

export type CallToActionOptions = {
	Text: string,
	OnClick: ((any) -> any) | nil,
}

export type SnackbarOptions = {
	CallToAction: string | CallToActionOptions?,
}

function SnackbarOptionUtils.createSnackbarOptions(options: SnackbarOptions): SnackbarOptions
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