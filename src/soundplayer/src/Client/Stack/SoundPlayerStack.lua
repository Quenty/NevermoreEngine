--!strict
--[=[
    @class SoundPlayerStack
]=]

local require = require(script.Parent.loader).load(script)

local LoopedSoundPlayer = require("LoopedSoundPlayer")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")
local SoundUtils = require("SoundUtils")
local TransitionModel = require("TransitionModel")
local ValueObject = require("ValueObject")
local t: any = require("t")

local SoundPlayerStack = setmetatable({}, TransitionModel)
SoundPlayerStack.ClassName = "SoundPlayerStack"
SoundPlayerStack.__index = SoundPlayerStack

export type SoundPlayerStack =
	typeof(setmetatable(
		{} :: {
			_stack: any, --ObservableSortedList.ObservableSortedList<LoopedSoundPlayer.LoopedSoundPlayer>,
		},
		{} :: typeof({ __index = SoundPlayerStack })
	))
	& TransitionModel.TransitionModel

function SoundPlayerStack.new(): SoundPlayerStack
	local self: SoundPlayerStack = setmetatable(TransitionModel.new() :: any, SoundPlayerStack)

	self._stack = self._maid:Add(ObservableSortedList.new())

	-- TODO: connect to visible + fire hiding finished when our stack is empty

	self._maid:GiveTask(self._stack:ObserveAtIndex(-1):Subscribe(function(soundPlayer)
		if soundPlayer then
			local maid = Maid.new()
			soundPlayer:Show()

			maid:GiveTask(function()
				if not soundPlayer.Destroy then
					return
				end

				soundPlayer:Hide()
			end)

			self._maid._playing = maid
		else
			self._maid._playing = nil
		end
	end))

	return self
end

function SoundPlayerStack.PushSoundPlayer(
	self: SoundPlayerStack,
	soundPlayer: LoopedSoundPlayer.LoopedSoundPlayer,
	priority: (Observable.Observable<number> | number)?
): () -> ()
	return self._stack:Add(soundPlayer, priority or 0)
end

return SoundPlayerStack
