--- Help manage the visibility of GUIs while only constructing the Gui while visible
-- @classmod GuiVisibleManager

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local cancellableDelay = require("cancellableDelay")

local GuiVisibleManager = setmetatable({}, BaseObject)
GuiVisibleManager.ClassName = "GuiVisibleManager"
GuiVisibleManager.__index = GuiVisibleManager

-- @param promiseNewPane Returns a promise for a new pane.
-- @param[opt=1] maxHideTime
function GuiVisibleManager.new(promiseNewPane, maxHideTime)
	local self = setmetatable(BaseObject.new(), GuiVisibleManager)

	self._maxHideTime = maxHideTime or 1
	self._promiseNewPane = promiseNewPane or error("No promiseNewPane")

	self._paneVisible = Instance.new("BoolValue")
	self._paneVisible.Value = false
	self._maid:GiveTask(self._paneVisible)

	self._showHandles = {}

	self._maid:GiveTask(self._paneVisible.Changed:Connect(function()
		self:_onPaneVisibleChanged()
	end))

	self.PaneVisibleChanged = self._paneVisible.Changed

	return self
end


function GuiVisibleManager:IsVisible()
	return self._paneVisible.Value
end

function GuiVisibleManager:BindToBoolValue(boolValue)
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

function GuiVisibleManager:CreateShowHandle()
	assert(self._showHandles, "Not initialized yet")

	local key = HttpService:GenerateGUID(false)

	self._showHandles[key] = true
	self:_updatePaneVisible()

	return {
		Destroy = function()
			if not self.Destroy then
				return
			end

			if self._showHandles[key] then
				self._showHandles[key] = nil
				self:_updatePaneVisible()
			end
		end
	};
end

function GuiVisibleManager:_updatePaneVisible()
	self._paneVisible.Value = next(self._showHandles) ~= nil
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
		if self._paneVisible.Value then
			pane:Show()
			maid._hideTask = nil
		else
			pane:Hide()

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