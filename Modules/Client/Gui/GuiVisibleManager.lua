---
-- @classmod GuiVisibleManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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

	self._theme = Instance.new("StringValue")
	self._theme.Value = "Light"
	self._maid:GiveTask(self._theme)

	self._showHandles = {}

	self._maid:GiveTask(self._paneVisible.Changed:Connect(function()
		self:_onPaneVisibleChanged()
	end))

	return self
end

function GuiVisibleManager:SetPreferredTheme(theme)
	assert(theme == "Light" or theme == "Dark")

	self._theme.Value = theme
end

function GuiVisibleManager:CreateShowHandle()
	assert(self._showHandles, "Not initialized yet")

	local key = HttpService:GenerateGUID(false)

	self._showHandles[key] = true
	self:_updatePaneVisible()

	return {
		Destroy = function()
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
		assert(not self._maid._paneMaid)
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
	assert(pane.SetVisible)
	assert(pane.SetPreferredTheme)
	assert(self._maid._paneMaid == maid)

	maid:GiveTask(pane)

	-- Theming
	pane:SetPreferredTheme(self._theme.Value)
	maid:GiveTask(self._theme.Changed:Connect(function()
		pane:SetPreferredTheme(self._theme.Value)
	end))

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