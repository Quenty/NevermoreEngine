--!strict
--[=[
	@class SaveSlotCmdrUtils
]=]

local require = require(script.Parent.loader).load(script)

local SaveSlotConstants = require("SaveSlotConstants")

local SaveSlotCmdrUtils = {}

function SaveSlotCmdrUtils.registerSlotIndexType(cmdr, saveSlotDataService)
	local slotIndex = {
		Transform = function(text: string, player: Player)
			local slots = saveSlotDataService:GetSlotList(player)
			local slotIndices = {}
			for _, metadata in slots do
				table.insert(slotIndices, tostring(metadata.SlotIndex))
			end

			-- The active ephemeral slot is deliberately absent from the slot list -- it is a throwaway
			-- session, not a save -- but it is still the slot the player is actually in, and admin tooling
			-- has to be able to name it (to persist it, export it, or end it). It answers to the reserved
			-- ephemeral index, which no real slot can hold, so it never shadows one. Offering it here is
			-- also what makes "." resolve while a session is active, since Default hands its index back
			-- through this finder.
			if saveSlotDataService:IsActiveSlotEphemeral(player) then
				table.insert(slotIndices, tostring(SaveSlotConstants.EPHEMERAL_SLOT_INDEX))
			end

			local matches = cmdr.Util.MakeFuzzyFinder(slotIndices)(text)
			if #matches > 0 then
				return matches
			end

			-- Autocomplete can only ever offer the executor's own slots -- Cmdr resolves types against the
			-- executor -- but these commands target other players, whose slots the executor cannot see. So
			-- any literal index typed out is accepted even when the executor has no such slot, which is what
			-- makes `export-save-slot SomeoneElse 3` possible. A target without that slot is reported by the
			-- command itself, which resolves the index per player.
			local literalIndex = tonumber(text)
			if literalIndex and (literalIndex >= 0) and (literalIndex % 1 == 0) then
				return { tostring(literalIndex) }
			end

			return matches
		end,
		Validate = function(keys)
			return #keys > 0, "Not a slot index."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return tonumber(keys[1])
		end,

		-- "." resolves to the player's current slot: the active slot when one is selected, otherwise the
		-- slot they last played. Cmdr feeds this string back through Transform, so it fuzzy matches the
		-- real slot. MakeListableType inherits Default, so "." works for delete-save-slot's list too.
		Default = function(player: Player): string?
			local slotId = saveSlotDataService:GetLastActiveSlotId(player)
			if not slotId then
				return nil
			end
			local metadata = saveSlotDataService:GetSlotMetadata(player, slotId)
			if type(metadata) ~= "table" then
				return nil
			end
			return tostring(metadata.SlotIndex)
		end,
	}

	cmdr.Registry:RegisterType("slotIndex", slotIndex)
	cmdr.Registry:RegisterType("slotIndices", cmdr.Util.MakeListableType(slotIndex))
end

return SaveSlotCmdrUtils
