--[=[
	@class SeatUtils
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")

local SeatUtils = {}

function SeatUtils.getPlayerOccupants(seats)
	local players = {}

	for _, seat in pairs(seats) do
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