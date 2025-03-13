--[=[
	A sustain model is much like a [TransitionModel] but is responsible for
	sustaining some animation or state. Useful to represent the sustained state
	of an animation or something.

	@class SustainModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")

local SustainModel = setmetatable({}, BaseObject)
SustainModel.ClassName = "SustainModel"
SustainModel.__index = SustainModel

function SustainModel.new()
	local self = setmetatable(BaseObject.new(), SustainModel)

	self._isSustained = false
	self._sustainCallback = nil

	self.SustainChanged = Signal.new() -- :Fire(isSustained, doNotAnimate)
	self._maid:GiveTask(self.SustainChanged)

	self._maid:GiveTask(self.SustainChanged:Connect(function(isSustained, doNotAnimate)
		if isSustained then
			self:_executeSustain(doNotAnimate)
		else
			self._maid._sustaining = nil
		end
	end))

	return self
end

--[=[
	Sets the callback which will handle sustaining the animation.

	@param sustainCallback function? -- Callback which should return a promise
]=]
function SustainModel:SetPromiseSustain(sustainCallback)
	assert(type(sustainCallback) == "function" or sustainCallback == nil, "Bad sustainCallback")

	self._sustainCallback = sustainCallback
end

--[=[
	Sets whether we should be sustaining or not

	@param isSustained boolean
	@param doNotAnimate boolean? -- True if animation should be skipped
]=]
function SustainModel:SetIsSustained(isSustained, doNotAnimate: boolean?)
	assert(type(isSustained) == "boolean", "Bad isSustained")

	if self._isSustained ~= isSustained then
		self._isSustained = isSustained
		self.SustainChanged:Fire(self._isSustained, doNotAnimate)
	end
end

--[=[
	Starts sustaining

	@param doNotAnimate boolean? -- True if animation should be skipped
]=]
function SustainModel:Sustain(doNotAnimate: boolean?)
	self:SetIsSustained(true, doNotAnimate)
end

--[=[
	Stops sustaining

	@param doNotAnimate boolean? -- True if animation should be skipped
]=]
function SustainModel:Stop(doNotAnimate: boolean?)
	self:SetIsSustained(false, doNotAnimate)
end

--[=[
	Starts sustaining. The promise will resolve when sustaining is done.
	If sustaining is already happening, it will not start, but will continue
	to sustain until the promise is done.

	@param doNotAnimate boolean? -- True if animation should be skipped
	@return Promise
]=]
function SustainModel:PromiseSustain(doNotAnimate: boolean?)
	self:Sustain(doNotAnimate)

	return self:_promiseSustained()
end

function SustainModel:_promiseSustained()
	if not self._isSustained then
		return Promise.resolved()
	end

	local promise = Promise.new()

	local maid = Maid.new()
	self._maid[promise] = maid

	maid:GiveTask(self.SustainChanged:Connect(function(isSustained)
		if not isSustained then
			promise:Resolve()
		end
	end))

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	return promise
end

function SustainModel:_executeSustain(doNotAnimate: boolean?)
	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)

	if self._sustainCallback then
		local result = self._sustainCallback(maid, doNotAnimate)
		if Promise.isPromise(result) then
			promise:Resolve(result)
		else
			promise:Reject()
			error(string.format("[SustainModel] - Expected promise to be returned from sustainCallback, got %q", tostring(result)))
		end
	end

	promise:Then(function()
		self:SetIsSustained(false, doNotAnimate)
	end)

	self._maid._sustaining = maid
end


return SustainModel