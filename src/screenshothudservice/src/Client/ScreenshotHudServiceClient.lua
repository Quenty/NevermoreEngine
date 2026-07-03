--!strict
--[=[
	@class ScreenshotHudServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local GuiService = game:GetService("GuiService")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ScreenshotHudModel = require("ScreenshotHudModel")
local ServiceBag = require("ServiceBag")
local StateStack = require("StateStack")

local ScreenshotHudServiceClient = {}
ScreenshotHudServiceClient.ServiceName = "ScreenshotHudServiceClient"

export type ScreenshotHudServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_screenshotHudState: StateStack.StateStack<ScreenshotHudModel.ScreenshotHudModel?>,
	},
	{} :: typeof({ __index = ScreenshotHudServiceClient })
))

function ScreenshotHudServiceClient.Init(self: ScreenshotHudServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._screenshotHudState = self._maid:Add(StateStack.new(nil :: ScreenshotHudModel.ScreenshotHudModel?))

	self._maid:GiveTask((RxBrioUtils.flatCombineLatest({
		model = self._screenshotHudState:Observe(),
		screenshotHUD = self:_observeScreenshotHudBrio(),
	}) :: any):Subscribe(function(state: any)
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
function ScreenshotHudServiceClient.PushModel(
	self: ScreenshotHudServiceClient,
	screenshotHudModel: ScreenshotHudModel.ScreenshotHudModel
): () -> ()
	local maid = Maid.new()

	maid:GiveTask(self._screenshotHudState:PushState(screenshotHudModel))

	return function()
		maid:DoCleaning()
	end
end

function ScreenshotHudServiceClient._bindModelToHUD(
	self: ScreenshotHudServiceClient,
	maid: Maid.Maid,
	model: ScreenshotHudModel.ScreenshotHudModel,
	screenshotHUD: any
): ()
	maid:GiveTask((Rx.combineLatest({
		visible = model:ObserveCloseButtonVisible(),
		position = model:ObserveCloseButtonPosition(),
	}) :: any):Subscribe(function(state: any)
		if state.visible then
			screenshotHUD.CloseButtonPosition = state.position
		else
			-- Hack to hide the close button
			screenshotHUD.CloseButtonPosition = UDim2.fromScale(2, 2)
		end
	end))

	-- I'm not sure why you would do this, but it's here
	maid:GiveTask((Rx.combineLatest({
		visible = model:ObserveCameraButtonVisible(),
		position = model:ObserveCameraButtonPosition(),
	}) :: any):Subscribe(function(state: any)
		if state.visible then
			screenshotHUD.CameraButtonPosition = state.position
		else
			-- Hack to hide the close button
			screenshotHUD.CameraButtonPosition = UDim2.fromScale(2, 2)
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

function ScreenshotHudServiceClient._observeScreenshotHudBrio(
	self: ScreenshotHudServiceClient
): Observable.Observable<Brio.Brio<Instance>>
	return RxInstanceUtils.observeLastNamedChildBrio(GuiService, "ScreenshotHud", "ScreenshotHud") :: any
end

function ScreenshotHudServiceClient.Destroy(self: ScreenshotHudServiceClient): ()
	self._maid:DoCleaning()
end

return ScreenshotHudServiceClient
