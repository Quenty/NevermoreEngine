--[=[
	@class AnimationPromiseUtils
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")

local AnimationPromiseUtils = {}

--[=[
	Promises that the track is finished

	@param animationTrack AnimationTrack
	@param endMarkerName string?
	@return Promise
]=]
function AnimationPromiseUtils.promiseFinished(
	animationTrack: AnimationTrack,
	endMarkerName: string?
): Promise.Promise<()>
	assert(typeof(animationTrack) == "Instance", "Bad animationTrack")
	assert(type(endMarkerName) == "string" or endMarkerName == nil, "Bad endMarkerName")
	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(animationTrack.Ended:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Stopped:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Destroying:Connect(function()
			promise:Resolve()
		end))

		if endMarkerName then
			maid:GiveTask(animationTrack:GetMarkerReachedSignal(endMarkerName):Connect(function()
				promise:Resolve()
			end))
		end
	end)

	return promise
end

--[=[
	Promises that the track has been loaded

	@param animationTrack AnimationTrack
	@return Promise
]=]
function AnimationPromiseUtils.promiseLoaded(animationTrack: AnimationTrack): Promise.Promise<()>
	assert(typeof(animationTrack) == "Instance", "Bad animationTrack")

	if animationTrack.Length > 0 then
		return Promise.resolved()
	end

	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(animationTrack:GetPropertyChangedSignal("Length"):Connect(function()
			if animationTrack.Length > 0 then
				promise:Resolve()
			end
		end))

		maid:GiveTask(RunService.Stepped:Connect(function()
			if animationTrack.Length > 0 then
				promise:Resolve()
			end
		end))

		maid:GiveTask(animationTrack.Ended:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Stopped:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Destroying:Connect(function()
			promise:Resolve()
		end))
	end)

	return promise
end

--[=[
	Promises that the track reached a keyframe or is finished

	@param animationTrack AnimationTrack
	@param keyframeName string
	@return Promise
]=]
function AnimationPromiseUtils.promiseKeyframeReached(animationTrack: AnimationTrack, keyframeName: string): Promise.Promise<()>
	assert(typeof(animationTrack) == "Instance", "Bad animationTrack")
	assert(type(keyframeName) == "string", "Bad endMarkerName")

	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(animationTrack.Ended:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Stopped:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack.Destroying:Connect(function()
			promise:Resolve()
		end))

		maid:GiveTask(animationTrack:GetMarkerReachedSignal(keyframeName):Connect(function()
			promise:Resolve()
		end))
	end)

	return promise
end


return AnimationPromiseUtils