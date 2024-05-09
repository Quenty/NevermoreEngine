--[=[
	Guarantees that only one snackbar is visible at once
	@class SnackbarServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Snackbar = require("Snackbar")
local SnackbarScreenGuiProvider = require("SnackbarScreenGuiProvider")
local Maid = require("Maid")
local Promise = require("Promise")
local SnackbarOptionUtils = require("SnackbarOptionUtils")
local PromptQueue = require("PromptQueue")

local SnackbarServiceClient = {}
SnackbarServiceClient.ServiceName = "SnackbarServiceClient"

function SnackbarServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._snackbarScreenGuiProvider = self._serviceBag:GetService(SnackbarScreenGuiProvider)
	self._screenGui = self._maid:Add(self._snackbarScreenGuiProvider:Get("SNACKBAR"))

	self._queue = self._maid:Add(PromptQueue.new())
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

--[=[
	Makes a snackbar and shows it to the user

	If options are included, in this format, a call to action will be presented to the player

	```
	{
		CallToAction = {
			Text = "Action";
			OnClick = function() end;
		};
	};
	```

	@param text string
	@param options SnackbarOptions
]=]
function SnackbarServiceClient:ShowSnackbar(text, options)
	assert(type(text) == "string", "text must be a string")
	assert(SnackbarOptionUtils.isSnackbarOptions(options) or options == nil, "Bad snackbarOptions")

	local snackbar = Snackbar.new(text, options)
	snackbar.Gui.Parent = self._screenGui

	self._queue:HideCurrent()

	self._maid:GivePromise(self._queue:Queue(snackbar))
		:Finally(function()
			snackbar:Destroy()
		end)

	return snackbar
end

function SnackbarServiceClient:HideCurrent(doNotAnimate)
	return self._queue:HideCurrent(doNotAnimate)
end

function SnackbarServiceClient:ClearQueue(doNotAnimate)
	self._queue:Clear(doNotAnimate)
end

function SnackbarServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SnackbarServiceClient