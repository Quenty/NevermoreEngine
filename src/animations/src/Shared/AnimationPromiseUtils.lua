--[=[
	@class AnimationPromiseUtils
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")

local AnimationPromiseUtils = {}

function AnimationPromiseUtils.promiseFinished(animationTrack)
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
	end)

	return promise
end

return AnimationPromiseUtils