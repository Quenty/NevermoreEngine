--!strict
--[=[
	Rx helpers over [PlayerMock], split out so PlayerMock itself stays free of Nevermore
	dependencies (DI-less code like dummy-mode Remoting requires it directly).

	@class PlayerMockUtils
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")

local PlayerMockUtils = {}

--[=[
	Observes the mock designated as the local player (see [PlayerMock.setMockedLocalPlayer]),
	emitting the current designation on subscribe and again whenever it changes. This replaces
	one-shot reading [PlayerMock.getMockedLocalPlayer], which goes stale when a test designates
	after the consumer initializes (designation is only required before bags Start, not before
	Init). Like the getter, this only ever emits the mock -- the real `Players.LocalPlayer`
	fallback stays an explicit read at the call site.

	Re-designating from one mock to another emits nil in between: the designation is carried as a
	CollectionService tag on the mock, and the switch removes the old tag before adding the new one.

	@return Observable<Player?>
]=]
function PlayerMockUtils.observeMockedLocalPlayer(): Observable.Observable<Player?>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local function update()
			sub:Fire(PlayerMock.getMockedLocalPlayer())
		end

		maid:GiveTask(CollectionService:GetInstanceAddedSignal(PlayerMock._LOCAL_PLAYER_TAG):Connect(update))
		maid:GiveTask(CollectionService:GetInstanceRemovedSignal(PlayerMock._LOCAL_PLAYER_TAG):Connect(update))
		update()

		return maid
	end) :: any
end

return PlayerMockUtils
