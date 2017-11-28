local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local DraggableSnackbar = LoadCustomLibrary("DraggableSnackbar")

--[[
class SnackbarManager

Description:
	Singleton, guarantees that only one snackbar is visible at once

API:
	WithPlayerGui(PlayerGui)
		Sets the PlayerGui/ScreenGui to render the snackbars in. Required before use

	MakeSnackbar(string Text, [table Options])
		Makes a snackbar and then shows it
	
		If options are included, in this format, a call to action will be presented to the player
		Options = {
			CallToAction = {
				Text = "Action";
				OnClick = function() end);
			};
		};

	WithSnackbarRemoteEvent(RemoteEvent)
		Initializes a RemoteEvent on the client to listen to new requests from the server to show a snackbar.
		Optional for regular use
]]

local SnackbarManager = {}
SnackbarManager.ClassName = "SnackbarManager"
SnackbarManager.__index = SnackbarManager

function SnackbarManager.new()
	local self = setmetatable({}, SnackbarManager)

	self.CurrentSnackbar = nil

	return self
end

--- Set snackbar manager PlayerGui and construct a ScreenGui to use
function SnackbarManager:WithPlayerGui(PlayerGui)
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "Snackbar_ScreenGui"
	ScreenGui.DisplayOrder = 10
	ScreenGui.Parent = PlayerGui

	return self:_withScreenGui(ScreenGui)
end

--- Sets the DisplayOrder of the ScreenGui
function SnackbarManager:WithDisplayOrder(DisplayOrder)
	assert(self.ScreenGui)
	
	self.ScreenGui.DisplayOrder = DisplayOrder or error("No DisplayOrder")
	return self
end

--- Automatically makes a snackbar and shows it
-- @param Text to show
-- @param Options See above
function SnackbarManager:MakeSnackbar(Text, Options)
	assert(self.ScreenGui, "Must call :WithPlayerGui(PlayerGui) bofore use")
	assert(type(Text) == "string", "Text must be a string")

	local NewSnackbar = DraggableSnackbar.new(self.ScreenGui, Text, true, Options)
	self:_showSnackbar(NewSnackbar)

	return NewSnackbar
end

--- Optional, sets a remote event to listen for feedback
function SnackbarManager:WithSnackbarRemoteEvent(RemoteEvent)
	assert(self.ScreenGui, "Must initialize PlayerGui before initializing RemoteEvent")
	
	self.RemoteEvent = RemoteEvent or error("No RemoteEvent")
	self.RemoteEvent.OnClientEvent:Connect(function(Text, Options)
		self:MakeSnackbar(Text, Options)
	end)
	
	return self
end

--- Cleanup existing snackbar
function SnackbarManager:_showSnackbar(Snackbar)
	assert(Snackbar, "Must send a Snackbar")

	if self.CurrentSnackbar == Snackbar and self.CurrentSnackbar.Visible then
		Snackbar:Dismiss()
	else
		local DismissedSnackbar = false

		if self.CurrentSnackbar then
			if self.CurrentSnackbar.Visible then
				self.CurrentSnackbar:Dismiss()
				self.CurrentSnackbar = nil
				DismissedSnackbar = true
			end
		end

		self.CurrentSnackbar = Snackbar
		if DismissedSnackbar then
			delay(Snackbar.FadeTime, function()
				if self.CurrentSnackbar == Snackbar then
					Snackbar:Show()
				end
			end)
		else
			Snackbar:Show()
		end
	end
end

--- Sets the ScreenGui to use
function SnackbarManager:_withScreenGui(ScreenGui)
	self.ScreenGui = ScreenGui or error("No ScreenGui")

	return self
end

return SnackbarManager