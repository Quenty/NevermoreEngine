--!strict
--[=[
	@class SaveSlotCmdrUtils
]=]

local SaveSlotCmdrUtils = {}

function SaveSlotCmdrUtils.registerSlotIndexType(cmdr, saveSlotDataService)
	local slotIndex = {
		Transform = function(text: string, player: Player)
			local slots = saveSlotDataService:GetSlotList(player)
			local slotIndices = {}
			for _, metadata in slots do
				table.insert(slotIndices, tostring(metadata.SlotIndex))
			end
			return cmdr.Util.MakeFuzzyFinder(slotIndices)(text)
		end,
		Validate = function(keys)
			return #keys > 0, "No matching slot."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return tonumber(keys[1])
		end,
	}

	cmdr.Registry:RegisterType("slotIndex", slotIndex)
	cmdr.Registry:RegisterType("slotIndices", cmdr.Util.MakeListableType(slotIndex))
end

return SaveSlotCmdrUtils
