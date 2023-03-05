--[=[
	This model deduplicates and handles transitions for showing, hiding, and
	toggling.

	@class TransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Promise = require("Promise")
local Maid = require("Maid")

local TransitionModel = setmetatable({}, BasicPane)
TransitionModel.ClassName = "TransitionModel"
TransitionModel.__index = TransitionModel

function TransitionModel.new()
	local self = setmetatable(BasicPane.new(), TransitionModel)

	self._isShowingComplete = Instance.new("BoolValue")
	self._isShowingComplete.Value = false
	self._maid:GiveTask(self._isShowingComplete)

	self._isHidingComplete = Instance.new("BoolValue")
	self._isHidingComplete.Value = false
	self._maid:GiveTask(self._isHidingComplete)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(visible, doNotAnimate)
		if visible then
			self:_executeShow(doNotAnimate)
		else
			self:_executeHide(doNotAnimate)
		end
	end))

	return self
end

function TransitionModel:PromiseShow(doNotAnimate)
	self:Show(doNotAnimate)

	return self:_promiseIsShown()
end

function TransitionModel:PromiseHide(doNotAnimate)
	self:Hide(doNotAnimate)

	return self:_promiseIsHidden()
end

function TransitionModel:PromiseToggle(doNotAnimate)
	if self:IsVisible() then
		return self:PromiseShow(doNotAnimate)
	else
		return self:PromiseHide(doNotAnimate)
	end
end

function TransitionModel:BindToPaneVisbility(pane)
	local maid = Maid.new()

	maid:GiveTask(pane.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self:SetVisible(isVisible, doNotAnimate)
	end))

	self:SetVisible(pane:IsVisible())

	self._maid._visibleBinding = maid

	return function()
		if self._maid._visibleBinding == maid then
			self._maid._visibleBinding = nil
		end
	end
end

function TransitionModel:SetPromiseShow(showCallback)
	assert(type(showCallback) == "function", "Bad showCallback")

	self._showCallback = showCallback
end

function TransitionModel:SetPromiseHide(hideCallback)
	assert(type(hideCallback) == "function", "Bad hideCallback")

	self._hideCallback = hideCallback
end

function TransitionModel:_promiseIsShown()
	if self._isShowingComplete.Value then
		return Promise.resolved()
	end

	local promise = Promise.new()

	local maid = Maid.new()
	self._maid[promise] = maid

	maid:GiveTask(self._isShowingComplete.Changed:Connect(function()
		if self._isShowingComplete.Value then
			promise:Resolve()
		end
	end))

	maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		if not isVisible then
			promise:Reject()
		end
	end))

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	return promise
end

function TransitionModel:_promiseIsHidden()
	if self._isHidingComplete.Value then
		return Promise.resolved()
	end

	local promise = Promise.new()

	local maid = Maid.new()
	self._maid[promise] = maid

	maid:GiveTask(self._isHidingComplete.Changed:Connect(function()
		if self._isHidingComplete.Value then
			promise:Resolve()
		end
	end))

	maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		if isVisible then
			promise:Reject()
		end
	end))

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	return promise
end

function TransitionModel:_executeShow(doNotAnimate)
	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)

	self._isHidingComplete.Value = false
	self._isShowingComplete.Value = false

	if self._showCallback then
		local result = self._showCallback(maid, doNotAnimate)
		if Promise.isPromise(result) then
			promise:Resolve(result)
		else
			promise:Reject()
			error(string.format("[TransitionModel] - Expected promise to be returned from showCallback, got %q", tostring(result)))
		end
	end

	promise:Then(function()
		self._isShowingComplete.Value = true
	end)

	self._maid._transition = maid
end

function TransitionModel:_executeHide(doNotAnimate)
	local maid = Maid.new()

	self._isHidingComplete.Value = false
	self._isShowingComplete.Value = false

	local promise = Promise.new()
	maid:GiveTask(promise)

	if self._hideCallback then
		local result = self._hideCallback(maid, doNotAnimate)
		if Promise.isPromise(result) then
			promise:Resolve(result)
		else
			promise:Reject()
			error(string.format("[TransitionModel] - Expected promise to be returned from showCallback, got %q", tostring(result)))
		end
	end

	promise:Then(function()
		self._isHidingComplete.Value = true
	end)

	self._maid._transition = maid
end


return TransitionModel