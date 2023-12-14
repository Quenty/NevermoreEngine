--[=[
	This model deduplicates and handles transitions for showing, hiding, and
	toggling. Inherits from [BasicPane]. See for more API.

	@class TransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Promise = require("Promise")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local TransitionModel = setmetatable({}, BasicPane)
TransitionModel.ClassName = "TransitionModel"
TransitionModel.__index = TransitionModel

--[=[
	A transition model that takes a set amount of time to show
	and hide. Can be used just like a [BasicPane] (in fact, it
	inherits from it), but additionally allows for variable length
	show and hide calls.

	@return TransitionModel
]=]
function TransitionModel.new()
	local self = setmetatable(BasicPane.new(), TransitionModel)

	self._isShowingComplete = ValueObject.new(false, "boolean")
	self._maid:GiveTask(self._isShowingComplete)

	self._isHidingComplete = ValueObject.new(false, "boolean")
	self._maid:GiveTask(self._isHidingComplete)

	self._showCallback = nil
	self._hideCallback = nil

	self._maid:GiveTask(self.VisibleChanged:Connect(function(visible, doNotAnimate)
		if visible then
			self:_executeShow(doNotAnimate)
		else
			self:_executeHide(doNotAnimate)
		end
	end))

	return self
end

--[=[
	Shows the model and promises when the showing is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function TransitionModel:PromiseShow(doNotAnimate)
	self:Show(doNotAnimate)

	return self:_promiseIsShown()
end

--[=[
	Hides the model and promises when the showing is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function TransitionModel:PromiseHide(doNotAnimate)
	self:Hide(doNotAnimate)

	return self:_promiseIsHidden()
end

--[=[
	Toggles the model and promises when the transition is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function TransitionModel:PromiseToggle(doNotAnimate)
	if self:IsVisible() then
		return self:PromiseShow(doNotAnimate)
	else
		return self:PromiseHide(doNotAnimate)
	end
end

--[=[
	Returns true if showing is complete
	@return boolean
]=]
function TransitionModel:IsShowingComplete()
	return self._isShowingComplete.Value
end

--[=[
	Returns true if hiding is complete
	@return boolean
]=]
function TransitionModel:IsHidingComplete()
	return self._isHidingComplete.Value
end

--[=[
	Observe is showing is complete
	@return Observable<boolean>
]=]
function TransitionModel:ObserveIsShowingComplete()
	return self._isShowingComplete:Observe()
end

--[=[
	Observe is hiding is complete
	@return Observable<boolean>
]=]
function TransitionModel:ObserveIsHidingComplete()
	return self._isHidingComplete:Observe()
end

--[=[
	Binds the transition model to the actual visiblity of the pane

	@param pane BasicPane
	@return function -- Cleanup function
]=]
function TransitionModel:BindToPaneVisbility(pane)
	local maid = Maid.new()

	maid:GiveTask(pane.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self:SetVisible(isVisible, doNotAnimate)
	end))
	maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		pane:SetVisible(isVisible, doNotAnimate)
	end))

	self:SetVisible(pane:IsVisible())

	self._maid._visibleBinding = maid

	return function()
		if self._maid._visibleBinding == maid then
			self._maid._visibleBinding = nil
		end
	end
end

--[=[
	Sets the callback which will handle showing the transition

	@param showCallback function? -- Callback which should return a promise
]=]
function TransitionModel:SetPromiseShow(showCallback)
	assert(type(showCallback) == "function" or showCallback == nil, "Bad showCallback")

	self._showCallback = showCallback
end

--[=[
	Sets the callback which will handle hiding the transition

	@param hideCallback function? -- Callback which should return a promise
]=]
function TransitionModel:SetPromiseHide(hideCallback)
	assert(type(hideCallback) == "function" or hideCallback == nil, "Bad hideCallback")

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
	self._maid._transition = nil

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

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
	else
		-- Immediately resolve
		promise:Resolve()
	end

	promise:Then(function()
		self._isShowingComplete.Value = true
	end)

	self._maid._transition = maid
end

function TransitionModel:_executeHide(doNotAnimate)
	self._maid._transition = nil

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	self._isHidingComplete.Value = false
	self._isShowingComplete.Value = false

	if self._hideCallback then
		local result = self._hideCallback(maid, doNotAnimate)
		if Promise.isPromise(result) then
			promise:Resolve(result)
		else
			promise:Reject()
			error(string.format("[TransitionModel] - Expected promise to be returned from hideCallback, got %q", tostring(result)))
		end
	else
		-- Immediately resolve
		promise:Resolve()
	end

	promise:Then(function()
		self._isHidingComplete.Value = true
	end)

	self._maid._transition = maid
end

return TransitionModel