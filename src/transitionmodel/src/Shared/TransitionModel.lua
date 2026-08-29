--!strict
--[=[
	This model deduplicates and handles transitions for showing, hiding, and
	toggling. Inherits from [BasicPane]. See for more API.

	@class TransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local TransitionModel = setmetatable({}, BasicPane)
TransitionModel.ClassName = "TransitionModel"
TransitionModel.__index = TransitionModel

export type ShowHideCallback = (maid: Maid.Maid, doNotAnimate: boolean?) -> Promise.Promise<()>

export type TransitionModel =
	typeof(setmetatable(
		{} :: {
			_isShowingComplete: ValueObject.ValueObject<boolean>,
			_isHidingComplete: ValueObject.ValueObject<boolean>,
			_hideCallback: ShowHideCallback?,
			_showCallback: ShowHideCallback?,

			HidingComplete: Signal.Signal<()>,
			ShowingComplete: Signal.Signal<()>,
			SkipAnimationRequested: Signal.Signal<boolean>,
		},
		{} :: typeof({ __index = TransitionModel })
	))
	& BasicPane.BasicPane

--[=[
	A transition model that takes a set amount of time to show
	and hide. Can be used just like a [BasicPane] (in fact, it
	inherits from it), but additionally allows for variable length
	show and hide calls.

	@return TransitionModel
]=]
function TransitionModel.new(): TransitionModel
	local self: TransitionModel = setmetatable(BasicPane.new() :: any, TransitionModel)

	self._isShowingComplete = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isHidingComplete = self._maid:Add(ValueObject.new(true, "boolean"))

	self.HidingComplete = self._maid:Add(Signal.new())
	self.ShowingComplete = self._maid:Add(Signal.new())

	--[=[
		Fires when [TransitionModel.SetVisible] is asked for the visibility the model already
		has, with doNotAnimate set.

		[BasicPane.VisibleChanged] deliberately stays quiet there -- the visibility did not
		change. But doNotAnimate is a command ("be there now"), not state, and a transition may
		still be in-flight, so there is real work left to do. The model restarts its own
		transition in response; subclasses listen here to snap anything else they animate
		alongside it, rather than each overriding [TransitionModel.SetVisible].

		@prop SkipAnimationRequested Signal<boolean>
		@within TransitionModel
	]=]
	self.SkipAnimationRequested = self._maid:Add(Signal.new() :: any) -- :Fire(isVisible)

	self._showCallback = nil
	self._hideCallback = nil

	self._maid:GiveTask(self.VisibleChanged:Connect(function(visible, doNotAnimate)
		if visible then
			self:_executeShow(doNotAnimate)
		else
			self:_executeHide(doNotAnimate)
		end
	end))

	self._maid:GiveTask(self.SkipAnimationRequested:Connect(function(isVisible)
		local isComplete = if isVisible then self:IsShowingComplete() else self:IsHidingComplete()
		if not isComplete then
			self:_restartTransition(true)
		end
	end))

	return self
end

--[=[
	Returnes true if it's a transition model

	@param value any
	@return boolean
]=]
function TransitionModel.isTransitionModel(value: any): boolean
	return DuckTypeUtils.isImplementation(TransitionModel, value)
end

--[=[
	Sets the transition model to be visible.

	Unlike [BasicPane.SetVisible], asking for the visibility the model already has with
	`doNotAnimate` is not a no-op. The boolean has not changed, but a transition may still be
	running and the caller wants it finished now, so this fires
	[TransitionModel.SkipAnimationRequested] instead of dropping the call.

	@param isVisible boolean -- Whether or not the model should be visible
	@param doNotAnimate boolean? -- True if this visiblity should not animate
]=]
function TransitionModel.SetVisible(self: TransitionModel, isVisible: boolean, doNotAnimate: boolean?)
	assert(type(isVisible) == "boolean", "Bad isVisible")

	if doNotAnimate and self:IsVisible() == isVisible then
		self.SkipAnimationRequested:Fire(isVisible)
		return
	end

	BasicPane.SetVisible(self, isVisible, doNotAnimate)
end

--[=[
	Shows the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TransitionModel.PromiseShow(self: TransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	local promise = self:_promiseIsShown()

	self:Show(doNotAnimate)

	return promise
end

--[=[
	Hides the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TransitionModel.PromiseHide(self: TransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	local promise = self:_promiseIsHidden()

	self:Hide(doNotAnimate)

	return promise
end

--[=[
	Toggles the model and promises when the transition is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TransitionModel.PromiseToggle(self: TransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	if self:IsVisible() then
		return self:PromiseHide(doNotAnimate)
	else
		return self:PromiseShow(doNotAnimate)
	end
end

--[=[
	Returns true if showing is complete
	@return boolean?
]=]
function TransitionModel.IsShowingComplete(self: TransitionModel): boolean
	return self._isShowingComplete.Value
end

--[=[
	Returns true if hiding is complete
	@return boolean?
]=]
function TransitionModel.IsHidingComplete(self: TransitionModel): boolean
	return self._isHidingComplete.Value
end

--[=[
	Observe is showing is complete
	@return Observable<boolean>
]=]
function TransitionModel.ObserveIsShowingComplete(self: TransitionModel): Observable.Observable<boolean>
	return self._isShowingComplete:Observe()
end

--[=[
	Observe is hiding is complete
	@return Observable<boolean>
]=]
function TransitionModel.ObserveIsHidingComplete(self: TransitionModel): Observable.Observable<boolean>
	return self._isHidingComplete:Observe()
end

--[=[
	Binds the transition model to the actual visiblity of the pane

	@param pane BasicPane
	@return function -- Cleanup function
]=]
function TransitionModel.BindToPaneVisbility(self: TransitionModel, pane: BasicPane.BasicPane): () -> ()
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
		-- Destroy nils out the maid, so an unbind that outlives the model has nothing to detach
		if not self.Destroy then
			return
		end

		if self._maid._visibleBinding == maid then
			self._maid._visibleBinding = nil
		end
	end
end

--[=[
	Sets the callback which will handle showing the transition

	@param showCallback function? -- Callback which should return a promise
]=]
function TransitionModel.SetPromiseShow(self: TransitionModel, showCallback)
	assert(type(showCallback) == "function" or showCallback == nil, "Bad showCallback")

	self._showCallback = showCallback
end

--[=[
	Sets the callback which will handle hiding the transition

	@param hideCallback function? -- Callback which should return a promise
]=]
function TransitionModel.SetPromiseHide(self: TransitionModel, hideCallback)
	assert(type(hideCallback) == "function" or hideCallback == nil, "Bad hideCallback")

	self._hideCallback = hideCallback
end

--[=[
	Re-runs the transition for the visibility the model already has.

	Transitions normally start off [BasicPane.VisibleChanged], which only fires when the
	boolean changes. Subclasses call this when something their show or hide callback reads
	has changed underneath it, so the callback runs again against the new state and the
	completion signals fire for the transition that actually happened.

	@private
	@param doNotAnimate boolean? -- True if the restarted transition should not animate
]=]
function TransitionModel._restartTransition(self: TransitionModel, doNotAnimate: boolean?)
	if self:IsVisible() then
		self:_executeShow(doNotAnimate)
	else
		self:_executeHide(doNotAnimate)
	end
end

function TransitionModel._promiseIsShown(self: TransitionModel): Promise.Promise<()>
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

function TransitionModel._promiseIsHidden(self: TransitionModel): Promise.Promise<()>
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

function TransitionModel._executeShow(self: TransitionModel, doNotAnimate: boolean?)
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
			error(
				string.format(
					"[TransitionModel] - Expected promise to be returned from showCallback, got %q",
					tostring(result)
				)
			)
		end
	else
		-- Immediately resolve
		promise:Resolve()
	end

	promise:Then(function()
		self._isShowingComplete.Value = true
		self.ShowingComplete:Fire()
	end)

	if self.Destroy then
		self._maid._transition = maid
	else
		maid:DoCleaning()
	end
end

function TransitionModel._executeHide(self: TransitionModel, doNotAnimate: boolean?)
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
			error(
				string.format(
					"[TransitionModel] - Expected promise to be returned from hideCallback, got %q",
					tostring(result)
				)
			)
		end
	else
		-- Immediately resolve
		promise:Resolve()
	end

	promise:Then(function()
		self._isHidingComplete.Value = true
		self.HidingComplete:Fire()
	end)

	if self.Destroy then
		self._maid._transition = maid
	else
		maid:DoCleaning()
	end
end

return TransitionModel
