--[=[
	@class ScreenshotHudServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")

local Maid = require("Maid")
local RxInstanceUtils = require("RxInstanceUtils")
local StateStack = require("StateStack")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local _ServiceBag = require("ServiceBag")

local ScreenshotHudServiceClient = {}
ScreenshotHudServiceClient.ServiceName = "ScreenshotHudServiceClient"

function ScreenshotHudServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._screenshotHudState = self._maid:Add(StateStack.new(nil))

	self._maid:GiveTask(RxBrioUtils.flatCombineLatest({
		model = self._screenshotHudState:Observe(),
		screenshotHUD = self:_observeScreenshotHudBrio(),
	}):Subscribe(function(state)
		self._maid._current = nil
		local maid = Maid.new()
		if state.model and state.screenshotHUD then
			self:_bindModelToHUD(maid, state.model, state.screenshotHUD)
			state.screenshotHUD.Visible = true
		else
			state.screenshotHUD.Visible = false
		end
		self._maid._current = maid
	end))
end

--[=[
	Pushes a new screenshotHudModel to show. This will fire .

	@param screenshotHudModel ScreenshotHudModel
	@return function -- cleanup code
]=]
function ScreenshotHudServiceClient:PushModel(screenshotHudModel)
	local maid = Maid.new()

	maid:GiveTask(self._screenshotHudState:PushState(screenshotHudModel))

	return function()
		maid:DoCleaning()
	end
end

function ScreenshotHudServiceClient:_bindModelToHUD(maid: Maid.Maid, model, screenshotHUD)
	maid:GiveTask(Rx.combineLatest({
		visible = model:ObserveCloseButtonVisible();
		position = model:ObserveCloseButtonPosition();
	}):Subscribe(function(state)
		if state.visible then
			screenshotHUD.CloseButtonPosition = state.position
		else
			-- Hack to hide the close button
			screenshotHUD.CloseButtonPosition = UDim2.new(2, 0, 2, 0)
		end
	end))

	-- I'm not sure why you would do this, but it's here
	maid:GiveTask(Rx.combineLatest({
		visible = model:ObserveCameraButtonVisible();
		position = model:ObserveCameraButtonPosition();
	}):Subscribe(function(state)
		if state.visible then
			screenshotHUD.CameraButtonPosition = state.position
		else
			-- Hack to hide the close button
			screenshotHUD.CameraButtonPosition = UDim2.new(2, 0, 2, 0)
		end
	end))

	maid:GiveTask(model:ObserveCameraButtonIcon():Subscribe(function(cameraButtonIcon)
		screenshotHUD.CameraButtonIcon = cameraButtonIcon
	end))
	maid:GiveTask(model:ObserveCloseWhenScreenshotTaken():Subscribe(function(closeWhenScreenshotTaken)
		screenshotHUD.CloseWhenScreenshotTaken = closeWhenScreenshotTaken
	end))
	maid:GiveTask(model:ObserveExperienceNameOverlayEnabled():Subscribe(function(experienceNameOverlayEnabled)
		screenshotHUD.ExperienceNameOverlayEnabled = experienceNameOverlayEnabled
	end))
	maid:GiveTask(model:ObserveUsernameOverlayEnabled():Subscribe(function(usernameOverlayEnabled)
		screenshotHUD.UsernameOverlayEnabled = usernameOverlayEnabled
	end))
	maid:GiveTask(model:ObserveOverlayFont():Subscribe(function(overlayFont)
		screenshotHUD.OverlayFont = overlayFont
	end))

	local alive = true
	maid:GiveTask(function()
		alive = false
	end)

	-- Visibility hiding will be taken care of at the higher level
	maid:GiveTask(screenshotHUD:GetPropertyChangedSignal("Visible"):Connect(function()
		if not model.Destroy then
			return
		end

		-- Reenable so we have a chance
		if not screenshotHUD.Visible then
			model:InternalFireClosedRequested()

			-- Reshow is we ned to
			task.defer(function()
				if alive and model.Destroy then
					if model:GetKeepOpen() then
						screenshotHUD.Visible = true
					end
				end
			end)
		end
	end))

	model:InternalNotifyVisible(true)
	maid:GiveTask(function()
		if model.Destroy then
			model:InternalNotifyVisible(false)
		end
	end)
end

function ScreenshotHudServiceClient:_observeScreenshotHudBrio()
	return RxInstanceUtils.observeLastNamedChildBrio(GuiService, "ScreenshotHud", "ScreenshotHud")
end

function ScreenshotHudServiceClient:Destroy()
	self._maid:DoCleaning()
end

return ScreenshotHudServiceClient