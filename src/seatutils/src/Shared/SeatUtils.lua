--!strict
--[=[
	@class SeatUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")

local SeatUtils = {}

--[=[
	Gets seat player occupants for all seats

	@param seats { Seat }
	@return { Player }
]=]
function SeatUtils.getPlayerOccupants(seats: { Seat | VehicleSeat }): { Player }
	local players = {}

	for _, seat in seats do
		local occupant = seat.Occupant
		if occupant then
			local player = CharacterUtils.getPlayerFromCharacter(occupant)
			if player then
				table.insert(players, player)
			end
		end
	end

	return players
end

return SeatUtils
