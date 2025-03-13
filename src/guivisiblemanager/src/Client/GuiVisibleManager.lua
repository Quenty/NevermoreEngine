--[=[
	Help manage the visibility of Guis while only constructing the Gui while visible.

	See [BasicPaneUtils.whenVisibleBrio] for a version that is written in Rx.

	@client
	@class GuiVisibleManager
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local cancellableDelay = require("cancellableDelay")
local ValueObject = require("ValueObject")

local GuiVisibleManager = setmetatable({}, BaseObject)
GuiVisibleManager.ClassName = "GuiVisibleManager"
GuiVisibleManager.__index = GuiVisibleManager

--[=[
	Constructs a new GuiVisibleManager.

	@param promiseNewPane (maid: Maid) -> Promise<TPane> -- Returns a promise for a new pane.
	@param maxHideTime number? -- Optional hide time
	@return GuiVisibleManager
]=]
function GuiVisibleManager.new(promiseNewPane, maxHideTime: number?)
	local self = setmetatable(BaseObject.new(), GuiVisibleManager)

	self._maxHideTime = maxHideTime or 1
	self._promiseNewPane = promiseNewPane or error("No promiseNewPane")

	self._nextDoNotAnimate = false

	self._paneVisible = self._maid:Add(ValueObject.new(false, "boolean"))

	self._showHandles = {}

	self._maid:GiveTask(self._paneVisible.Changed:Connect(function()
		self:_onPaneVisibleChanged()
	end))

	self.PaneVisibleChanged = self._paneVisible.Changed

	return self
end

--[=[
	Returns whether the Gui is visible.

	@return boolean
]=]
function GuiVisibleManager:IsVisible(): boolean
	return self._paneVisible.Value
end

--[=[
	Binds visiblity to the bool value being true. There could be other ways
	that the Gui is shown if this is not set.

	@param boolValue BoolValue
]=]
function GuiVisibleManager:BindToBoolValue(boolValue: BoolValue)
	assert(boolValue, "Must have boolValue")
	assert(not self._boundBoolValue, "Already bound")

	self._boundBoolValue = boolValue

	self._maid:GiveTask(self._boundBoolValue.Changed:Connect(function()
		if self._boundBoolValue.Value then
			self._maid._boundShowHandle = self:CreateShowHandle()
		else
			self._maid._boundShowHandle = nil
		end
	end))

	if self._boundBoolValue.Value then
		self._maid._boundShowHandle = self:CreateShowHandle()
	end
end

--[=[
	Creates a handle that will force the gui to be rendered. Clean up the task
	to stop the showing.

	@param doNotAnimate boolean?
	@return MaidTask
]=]
function GuiVisibleManager:CreateShowHandle(doNotAnimate: boolean?)
	assert(self._showHandles, "Not initialized yet")

	local key = HttpService:GenerateGUID(false)

	self._showHandles[key] = true
	self:_updatePaneVisible(doNotAnimate)

	return {
		Destroy = function()
			if not self.Destroy then
				return
			end

			if self._showHandles[key] then
				self._showHandles[key] = nil
				self:_updatePaneVisible()
			end
		end,
	}
end

function GuiVisibleManager:_updatePaneVisible(doNotAnimate: boolean?)
	local nextValue = next(self._showHandles) ~= nil
	if nextValue ~= self._paneVisible.Value then
		self._nextDoNotAnimate = doNotAnimate
		self._paneVisible.Value = nextValue
	end
end

function GuiVisibleManager:_onPaneVisibleChanged()
	if self._maid._paneMaid then
		return
	end

	if not self._paneVisible.Value then
		assert(not self._maid._paneMaid, "_paneMaid is gone")
		return
	end

	local maid = Maid.new()
	self._maid._paneMaid = maid

	self._promiseNewPane(maid)
		:Then(function(pane)
			if self._maid._paneMaid == maid then
				self:_handleNewPane(maid, pane)
			else
				warn("[GuiVisibleManager] - Pane is not needed, promise took too long")
				pane:Destroy()
			end
		end)
end

function GuiVisibleManager:_handleNewPane(maid, pane)
	assert(pane.SetVisible, "No SetVisible on self, already destroyed")
	assert(self._maid._paneMaid == maid, "Bad maid")

	maid:GiveTask(pane)

	local function updateVisible()
		local doNotAnimate = self._nextDoNotAnimate
		self._nextDoNotAnimate = false

		if self._paneVisible.Value then
			pane:Show(doNotAnimate)
			maid._hideTask = nil
		else
			pane:Hide(doNotAnimate)

			-- cleanup after a given amount of time
			maid._hideTask = cancellableDelay(self._maxHideTime, function()
				if self._maid._paneMaid == maid then
					self._maid._paneMaid = nil
				end
			end)
		end
	end

	-- Bind update
	maid:GiveTask(self._paneVisible.Changed:Connect(updateVisible))
	updateVisible()
end

return GuiVisibleManager