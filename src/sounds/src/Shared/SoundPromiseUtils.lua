--!strict
--[=[
	Utility functions involving sounds and their state
	@class SoundPromiseUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")
local PromiseUtils = require("PromiseUtils")

local SoundPromiseUtils = {}

--[=[
	Promises that a sound is loaded
	@param sound Sound
	@return Promise
]=]
function SoundPromiseUtils.promiseLoaded(sound: Sound): Promise.Promise<()>
	if sound.IsLoaded then
		return Promise.resolved()
	end

	local promise = Promise.new()
	local maid = Maid.new()

	maid:GiveTask(sound:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		if sound.IsLoaded then
			promise:Resolve()
		end
	end))

	maid:GiveTask(sound.Loaded:Connect(function()
		if sound.IsLoaded then
			promise:Resolve()
		end
	end))

	promise:Finally(function()
		maid:DoCleaning()
	end)

	return promise
end

function SoundPromiseUtils.promisePlayed(sound: Sound): Promise.Promise<()>
	return SoundPromiseUtils.promiseLoaded(sound):Then(function()
		return PromiseUtils.delayed(sound.TimeLength)
	end)
end

function SoundPromiseUtils.promiseLooped(sound: Sound): Promise.Promise<()>
	local promise = Promise.new()

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(sound.DidLoop:Connect(function()
			promise:Resolve()
		end))
	end)

	return promise
end
--[=[
	Promises that all sounds are loaded
	@param sounds { Sound }
	@return Promise
]=]
function SoundPromiseUtils.promiseAllSoundsLoaded(sounds: { Sound }): Promise.Promise<()>
	local promises = {}
	for _, sound in sounds do
		table.insert(promises, SoundPromiseUtils.promiseLoaded(sound))
	end
	return PromiseUtils.all(promises)
end

return SoundPromiseUtils
