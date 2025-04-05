--[=[
	@class ImageLabelLoaded
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ContentProviderUtils = require("ContentProviderUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local ImageLabelLoaded = setmetatable({}, BaseObject)
ImageLabelLoaded.ClassName = "ImageLabelLoaded"
ImageLabelLoaded.__index = ImageLabelLoaded

function ImageLabelLoaded.new()
	local self = setmetatable(BaseObject.new(), ImageLabelLoaded)

	self._isLoaded = self._maid:Add(ValueObject.new(false, "boolean"))
	self._preloadImage = self._maid:Add(ValueObject.new(true, "boolean"))

	self._defaultTimeout = 1

	self.ImageChanged = self._maid:Add(Signal.new())

	return self
end

function ImageLabelLoaded:SetDefaultTimeout(defaultTimeout: number?)
	assert(type(defaultTimeout) == "number" or defaultTimeout == nil, "Bad defaultTimeout")

	self._defaultTimeout = defaultTimeout
end

function ImageLabelLoaded:IsLoaded(): boolean
	return self._isLoaded.Value
end

function ImageLabelLoaded:SetPreloadImage(preloadImage: boolean)
	assert(type(preloadImage) == "boolean", "Bad preloadImage")

	self._preloadImage.Value = preloadImage
end

function ImageLabelLoaded:PromiseLoaded(timeout: number?)
	assert(type(timeout) == "number" or timeout == nil, "Bad timeout")

	local originalTimeout = timeout
	timeout = timeout or self._defaultTimeout

	if self._isLoaded.Value then
		return Promise.resolved()
	end

	local promise = Promise.new()

	local maid = Maid.new()
	self._maid[promise] = maid

	maid:GiveTask(self._isLoaded.Changed:Connect(function()
		if self._isLoaded.Value then
			promise:Resolve()
		end
	end))

	maid:GiveTask(self.ImageChanged:Connect(function(isVisible)
		if not isVisible then
			promise:Reject()
		end
	end))

	if timeout then
		maid:GiveTask(task.delay(timeout, function()
			if originalTimeout then
				promise:Reject("[ImageLabelLoaded] - Failed to load image after default timeout time")
			else
				promise:Reject()
			end
		end))
	end

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	return promise
end

function ImageLabelLoaded:SetImageLabel(imageLabel: ImageLabel?)
	assert(typeof(imageLabel) == "Instance" and imageLabel:IsA("ImageLabel") or imageLabel == nil, "Bad imageLabel")
	if self._imageLabel == imageLabel then
		return
	end

	local maid = Maid.new()

	self._imageLabel = imageLabel

	if self._imageLabel then
		self._isLoaded.Value = self._imageLabel.IsLoaded

		maid:GiveTask(self._imageLabel:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			self._isLoaded.Value = self._imageLabel.IsLoaded
		end))

		-- Setup preloading as necessary
		maid:GiveTask(self._preloadImage:Observe():Pipe({
			Rx.switchMap(function(preload)
				if preload then
					return Rx.combineLatest({
						isLoaded = self._isLoaded:Observe();
						image = RxInstanceUtils.observeProperty(self._imageLabel, "Image");
					})
				else
					return Rx.EMPTY
				end
			end);
		}):Subscribe(function(state)
			if not state.isLoaded and state.image ~= "" then
				maid:GivePromise(ContentProviderUtils.promisePreload({self._imageLabel}))
					:Then(function()
						self._isLoaded.Value = true
					end)
			end
		end))
	else
		self._isLoaded.Value = false
	end

	self.ImageChanged:Fire()

	self._maid._imageLabelMaid = maid
end

return ImageLabelLoaded