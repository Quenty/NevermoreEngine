--!strict
--[=[
    @class SoundPlayerStack
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local LoopedSoundPlayer = require("LoopedSoundPlayer")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSortedList = require("ObservableSortedList")
local Signal = require("Signal")

local SoundPlayerStack = setmetatable({}, BaseObject)
SoundPlayerStack.ClassName = "SoundPlayerStack"
SoundPlayerStack.__index = SoundPlayerStack

export type SoundPlayerStack =
	typeof(setmetatable(
		{} :: {
			_stack: any, --ObservableSortedList.ObservableSortedList<LoopedSoundPlayer.LoopedSoundPlayer>,
			HidingComplete: Signal.Signal<()>,
		},
		{} :: typeof({ __index = SoundPlayerStack })
	))
	& BaseObject.BaseObject

function SoundPlayerStack.new(): SoundPlayerStack
	local self: SoundPlayerStack = setmetatable(BaseObject.new() :: any, SoundPlayerStack)

	self._stack = self._maid:Add(ObservableSortedList.new())

	-- Used to notify the LayeredSoundHelper that we've finished hiding
	-- and have no more sound players to play.
	self.HidingComplete = self._maid:Add(Signal.new())

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
			self.HidingComplete:Fire()
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
