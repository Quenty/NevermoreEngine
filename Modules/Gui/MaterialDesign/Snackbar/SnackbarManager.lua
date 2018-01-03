--- Guarantees that only one snackbar is visible at once
-- @module SnackbarManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DraggableSnackbar = require("DraggableSnackbar")

local SnackbarManager = {}
SnackbarManager.ClassName = "SnackbarManager"
SnackbarManager.__index = SnackbarManager

function SnackbarManager.new()
	local self = setmetatable({}, SnackbarManager)

	self._currentSnackbar = nil

	return self
end

--- Set snackbar manager PlayerGui and construct a screenGui to use
function SnackbarManager:WithPlayerGui(playerGui)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Snackbar_ScreenGui"
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	return self:_withScreenGui(screenGui)
end

--- Sets the screenGui to use
function SnackbarManager:_withScreenGui(screenGui)
	self._screenGui = screenGui or error("No screenGui")

	return self
end

--- Sets the DisplayOrder of the screenGui
function SnackbarManager:WithDisplayOrder(displayOrder)
	assert(self._screenGui)
	
	self._screenGui.DisplayOrder = displayOrder or error("No DisplayOrder")
	return self
end

--- Automatically makes a snackbar and shows it
-- @param text to show
-- @param[opt] options
--[[
		If options are included, in this format, a call to action will be presented to the player
		options = {
			CallToAction = {
				Text = "Action";
				OnClick = function() end);
			};
		};
]]
function SnackbarManager:MakeSnackbar(text, options)
	assert(self._screenGui, "Must call :WithPlayerGui(PlayerGui) bofore use")
	assert(type(text) == "string", "text must be a string")

	local NewSnackbar = DraggableSnackbar.new(self._screenGui, text, true, options)
	self:_showSnackbar(NewSnackbar)

	return NewSnackbar
end

--- Initializes a remoteEvent on the client to listen to new requests from the server to show a snackbar.
-- Optional for regular use
function SnackbarManager:WithSnackbarRemoteEvent(remoteEvent)
	assert(self._screenGui, "Must initialize PlayerGui before initializing remoteEvent")
	
	self._remoteEvent = remoteEvent or error("No remoteEvent")
	self._remoteEvent.OnClientEvent:Connect(function(Text, Options)
		self:MakeSnackbar(Text, Options)
	end)
	
	return self
end

--- Cleanup existing snackbar
function SnackbarManager:_showSnackbar(snackbar)
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
			delay(snackbar.FadeTime, function()
				if self._currentSnackbar == snackbar then
					snackbar:Show()
				end
			end)
		else
			snackbar:Show()
		end
	end
end



return SnackbarManager