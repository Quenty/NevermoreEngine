--!strict
--[=[
	Helps observe teleports.

	@class RxTeleportUtils
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local ValueObject = require("ValueObject")
local Brio = require("Brio")

local RxTeleportUtils = {}

--[=[
	Returns an observable that exists for the lifetime that the player is attempting to
	teleport to the given placeId.

	@param player Player
	@return Observable<Brio<number>>
]=]
function RxTeleportUtils.observeTeleportBrio(player: Player): Observable.Observable<Brio.Brio<number>>
	assert(typeof(player) == "Instance", "Bad player")

	return Observable.new(function(sub)
		local maid = Maid.new()
		local teleportPlaceId: ValueObject.ValueObject<number?> = maid:Add(ValueObject.new(nil))

		maid:GiveTask(player.OnTeleport:Connect(function(teleportState, placeId)
			if
				teleportState == Enum.TeleportState.RequestedFromServer
				or teleportState == Enum.TeleportState.Started
				or teleportState == Enum.TeleportState.WaitingForServer
				or teleportState == Enum.TeleportState.InProgress
			then
				teleportPlaceId.Value = placeId
			elseif teleportState == Enum.TeleportState.Failed then
				teleportPlaceId.Value = nil
			else
				warn(
					string.format(
						"[RxTeleportUtils.observeTeleportBrio] - Unknown teleport state %s",
						tostring(teleportState)
					)
				)
			end
		end))

		maid:GiveTask(teleportPlaceId:Observe():Subscribe(function(placeId)
			if placeId then
				local brio = Brio.new(placeId)
				maid._current = brio

				sub:Fire(brio)
			else
				maid._current = nil
			end
		end))

		return maid
	end) :: any
end

return RxTeleportUtils
