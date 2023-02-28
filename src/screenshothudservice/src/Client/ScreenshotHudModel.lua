--[=[
	@class ScreenshotHudModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")

local ScreenshotHudModel = setmetatable({}, BaseObject)
ScreenshotHudModel.ClassName = "ScreenshotHudModel"
ScreenshotHudModel.__index = ScreenshotHudModel

function ScreenshotHudModel.new()
	local self = setmetatable(BaseObject.new(), ScreenshotHudModel)

	self._cameraButtonIcon = Instance.new("StringValue")
	self._cameraButtonIcon.Value = ""
	self._maid:GiveTask(self._cameraButtonIcon)

	self._cameraButtonPosition = ValueObject.new(UDim2.new(0, 0, 0, 0))
	self._maid:GiveTask(self._cameraButtonPosition)

	self._closeButtonPosition = ValueObject.new(UDim2.new(0, 0, 0, 0))
	self._maid:GiveTask(self._closeButtonPosition)

	self._closeWhenScreenshotTaken = Instance.new("BoolValue")
	self._closeWhenScreenshotTaken.Value = false
	self._maid:GiveTask(self._closeWhenScreenshotTaken)

	self._experienceNameOverlayEnabled = Instance.new("BoolValue")
	self._experienceNameOverlayEnabled.Value = false
	self._maid:GiveTask(self._experienceNameOverlayEnabled)

	self._overlayFont = ValueObject.new(Enum.Font.SourceSans)
	self._maid:GiveTask(self._overlayFont)

	self._usernameOverlayEnabled = Instance.new("BoolValue")
	self._usernameOverlayEnabled.Value = false
	self._maid:GiveTask(self._usernameOverlayEnabled)

	self._visible = Instance.new("BoolValue")
	self._visible.Value = false
	self._maid:GiveTask(self._visible)

	self._cameraButtonVisible = Instance.new("BoolValue")
	self._cameraButtonVisible.Value = true
	self._maid:GiveTask(self._cameraButtonVisible)

	self._closeButtonVisible = Instance.new("BoolValue")
	self._closeButtonVisible.Value = false
	self._maid:GiveTask(self._closeButtonVisible)

	self._keepOpen = Instance.new("BoolValue")
	self._keepOpen.Value = true
	self._maid:GiveTask(self._keepOpen)

	self.CloseRequested = Signal.new()
	self._maid:GiveTask(self.CloseRequested)

	return self
end

--[=[
	Sets whether the close button is visible
	@param closeButtonVisible boolean
]=]
function ScreenshotHudModel:SetCloseButtonVisible(closeButtonVisible)
	assert(typeof(closeButtonVisible) == "boolean", "Bad closeButtonVisible")

	self._closeButtonVisible.Value = closeButtonVisible
end

--[=[
	Observes close button visiblity
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveCloseButtonVisible()
	return RxInstanceUtils.observeProperty(self._closeButtonVisible, "Value")
end

--[=[
	Sets whether the camera button is visible
	@param cameraButtonVisible boolean
]=]
function ScreenshotHudModel:SetCameraButtonVisible(cameraButtonVisible)
	assert(typeof(cameraButtonVisible) == "boolean", "Bad cameraButtonVisible")

	self._cameraButtonVisible.Value = cameraButtonVisible
end

--[=[
	Observes camera button visiblity
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveCameraButtonVisible()
	return RxInstanceUtils.observeProperty(self._cameraButtonVisible, "Value")
end

--[=[
	Sets whether we should try to keep the UI open
	@param keepOpen boolean
]=]
function ScreenshotHudModel:SetKeepOpen(keepOpen)
	assert(typeof(keepOpen) == "boolean", "Bad keepOpen")

	self._keepOpen.Value = keepOpen
end

--[=[
	Gets whether we should try to keep the UI open
	@return boolean
]=]
function ScreenshotHudModel:GetKeepOpen()
	return self._keepOpen.Value
end

--[=[
	Sets the close button's position
	@param visible boolean
]=]
function ScreenshotHudModel:SetCloseButtonVisible(visible)
	assert(type(visible) == "boolean", "Bad visible")

	self._closeButtonPosition.Value = visible
end


--[=[
	Sets the close button's position
	@param position UDim2 | nil
]=]
function ScreenshotHudModel:SetCloseButtonPosition(position)
	assert(typeof(position) == "UDim2" or position == nil, "Bad position")

	self._closeButtonPosition.Value = position or UDim2.new(0, 0, 0, 0)
end

--[=[
	Observes the close button's position
	@return Observable<UDim2>
]=]
function ScreenshotHudModel:ObserveCloseButtonPosition()
	return self._closeButtonPosition:Observe()
end

--[=[
	Sets the camera button's position
	@param position UDim2 | nil
]=]
function ScreenshotHudModel:SetCameraButtonPosition(position)
	assert(typeof(position) == "UDim2" or position == nil, "Bad position")

	self._cameraButtonPosition.Value = position or UDim2.new(0, 0, 0, 0)
end

--[=[
	Observes the camera button's position
	@return Observable<UDim2>
]=]
function ScreenshotHudModel:ObserveCameraButtonPosition()
	return self._cameraButtonPosition:Observe()
end

--[=[
	Sets the overlay font
	@param overlayFont Font
]=]
function ScreenshotHudModel:SetOverlayFont(overlayFont)
	assert(typeof(overlayFont) == "EnumItem" or overlayFont == nil, "Bad overlayFont")

	self._overlayFont.Value = overlayFont
end

--[=[
	Observes the overlay font
	@return Observable<Font>
]=]
function ScreenshotHudModel:ObserveOverlayFont()
	return self._overlayFont:Observe()
end

--[=[
	Sets the camera button's icon.

	@param icon string | nil
]=]
function ScreenshotHudModel:SetCameraButtonIcon(icon)
	assert(type(icon) == "string" or icon == nil, "Bad icon")

	self._cameraButtonIcon.Value = icon or ""
end

--[=[
	Observes the camera button's icon

	@return Observable<string>
]=]
function ScreenshotHudModel:ObserveCameraButtonIcon()
	return RxInstanceUtils.observeProperty(self._cameraButtonIcon, "Value")
end

--[=[
	Sets whether to close after a screenshot if taken

	@param closeWhenScreenshotTaken boolean
]=]
function ScreenshotHudModel:SetCloseWhenScreenshotTaken(closeWhenScreenshotTaken)
	assert(type(closeWhenScreenshotTaken) == "boolean", "Bad closeWhenScreenshotTaken")

	self._closeWhenScreenshotTaken.Value = closeWhenScreenshotTaken
end

--[=[
	Returns whether the model will try to close if a screenshot is taken
	@return boolean
]=]
function ScreenshotHudModel:GetCloseWhenScreenshotTaken()
	return self._closeWhenScreenshotTaken.Value
end

--[=[
	Observes whether a screenshot is taken
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveCloseWhenScreenshotTaken()
	return RxInstanceUtils.observeProperty(self._closeWhenScreenshotTaken, "Value")
end

--[=[
	Sets whether to experience name overlay should be enabled
	@param experienceNameOverlayEnabled boolean
]=]
function ScreenshotHudModel:SetExperienceNameOverlayEnabled(experienceNameOverlayEnabled)
	assert(type(experienceNameOverlayEnabled) == "boolean", "Bad experienceNameOverlayEnabled")

	self._experienceNameOverlayEnabled.Value = experienceNameOverlayEnabled
end

--[=[
	Observes whether the experience name overlay is enabled
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveExperienceNameOverlayEnabled()
	return RxInstanceUtils.observeProperty(self._experienceNameOverlayEnabled, "Value")
end

--[=[
	Sets whether to username overlay should be enabled
	@param usernameOverlayEnabled boolean
]=]
function ScreenshotHudModel:SetUsernameOverlayEnabled(usernameOverlayEnabled)
	assert(type(usernameOverlayEnabled) == "boolean", "Bad usernameOverlayEnabled")

	self._usernameOverlayEnabled.Value = usernameOverlayEnabled
end

--[=[
	Observes whether the username name overlay is enabled
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveUsernameOverlayEnabled()
	return RxInstanceUtils.observeProperty(self._usernameOverlayEnabled, "Value")
end

--[=[
	Observes whilet he model is visible
	@return Observable<boolean>
]=]
function ScreenshotHudModel:ObserveVisible()
	return RxInstanceUtils.observeProperty(self._visible, "Value")
end

function ScreenshotHudModel:InternalNotifyVisible(isVisible)
	self._visible.Value = isVisible
end

function ScreenshotHudModel:InternalFireClosedRequested()
	self.CloseRequested:Fire()
end

return ScreenshotHudModel