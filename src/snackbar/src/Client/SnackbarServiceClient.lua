--[=[
	Guarantees that only one snackbar is visible at once
	@class SnackbarServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local DraggableSnackbar = require("DraggableSnackbar")

local SnackbarServiceClient = {}
SnackbarServiceClient.ServiceName = "SnackbarServiceClient"

function SnackbarServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._currentSnackbar = nil
end

--[=[
	Sets the screenGui to use

	@param screenGui ScreenGui
	@return SnackbarServiceClient
]=]
function SnackbarServiceClient:SetScreenGui(screenGui)
	self._screenGui = screenGui or error("No screenGui")

	return self
end

-- Automatically makes a snackbar and shows it
-- @param text to show
-- @param[opt] options
--[[
		If options are included, in this format, a call to action will be presented to the player
		options = {
			CallToAction = {
				Text = "Action";
				OnClick = function() end;
			};
		};
]]
function SnackbarServiceClient:ShowSnackbar(text, options)
	assert(type(text) == "string", "text must be a string")

	local snackbar = DraggableSnackbar.new(self._screenGui, text, true, options)
	self:_showSnackbar(snackbar)

	return snackbar
end

function SnackbarServiceClient:_showSnackbar(snackbar)
	assert(snackbar, "Must send a snackbar")

	if self._currentSnackbar == snackbar and self._currentSnackbar:IsVisible() then
		snackbar:Dismiss()
	else
		local dismissedSnackbar = false

		if self._currentSnackbar then
			if self._currentSnackbar:IsVisible() then
				self._currentSnackbar:Dismiss()
				self._currentSnackbar = nil
				dismissedSnackbar = true
			end
		end

		self._currentSnackbar = snackbar
		if dismissedSnackbar then
			task.delay(snackbar.FadeTime, function()
				if self._currentSnackbar == snackbar then
					snackbar:Show()
				end
			end)
		else
			snackbar:Show()
		end
	end
end

return SnackbarServiceClient