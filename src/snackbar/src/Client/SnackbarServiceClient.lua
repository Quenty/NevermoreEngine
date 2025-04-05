--[=[
	Guarantees that only one snackbar is visible at once
	@class SnackbarServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Snackbar = require("Snackbar")
local SnackbarScreenGuiProvider = require("SnackbarScreenGuiProvider")
local Maid = require("Maid")
local SnackbarOptionUtils = require("SnackbarOptionUtils")
local PromptQueue = require("PromptQueue")
local _ServiceBag = require("ServiceBag")

local SnackbarServiceClient = {}
SnackbarServiceClient.ServiceName = "SnackbarServiceClient"

--[=[
	Initializes the snackbar service. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function SnackbarServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
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
	Makes a snackbar and shows it to the user in a queue.

	```lua
	local snackbarServiceClient = serviceBag:GetService(SnackbarServiceClient)

	snackbarServiceClient:ShowSnackbar("Settings saved!", {
		CallToAction = {
			Text = "Undo";
			OnClick = function()
				print("Activated action")
			end;
		}
	})
	```

	@param text string
	@param options SnackbarOptions
]=]
function SnackbarServiceClient:ShowSnackbar(
	text: string,
	options: SnackbarOptionUtils.SnackbarOptions?
): Snackbar.Snackbar
	assert(type(text) == "string", "text must be a string")
	assert(SnackbarOptionUtils.isSnackbarOptions(options) or options == nil, "Bad snackbarOptions")

	local snackbar = Snackbar.new(text, options)
	snackbar.Gui.Parent = self._screenGui

	self._queue:HideCurrent()

	self._maid:GivePromise(self._queue:Queue(snackbar)):Finally(function()
		snackbar:Destroy()
	end)

	return snackbar
end

--[=[
	Hides the current snackbar shown in the queue

	@param doNotAnimate boolean
]=]
function SnackbarServiceClient:HideCurrent(doNotAnimate: boolean?)
	return self._queue:HideCurrent(doNotAnimate)
end

--[=[
	Completely clears the queue

	@param doNotAnimate boolean
]=]
function SnackbarServiceClient:ClearQueue(doNotAnimate: boolean?)
	self._queue:Clear(doNotAnimate)
end

--[=[
	Cleans up the snackbar service!
]=]
function SnackbarServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SnackbarServiceClient