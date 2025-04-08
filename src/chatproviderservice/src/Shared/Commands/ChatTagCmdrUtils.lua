--!strict
--[=[
	@class ChatTagCmdrUtils
]=]

local ChatTagCmdrUtils = {}

function ChatTagCmdrUtils.registerChatTagKeys(cmdr, chatProviderService)
	local chatTagKey = {
		Transform = function(text)
			local chatTagKeyList = chatProviderService:GetChatTagKeyList()
			local find = cmdr.Util.MakeFuzzyFinder(chatTagKeyList)
			return find(text)
		end;
		Validate = function(keys)
			return #keys > 0, "No chat tag with that key could be found."
		end,
		Autocomplete = function(keys)
			return keys
		end,
		Parse = function(keys)
			return keys[1]
		end;
	}

	cmdr.Registry:RegisterType("chatTagKey", chatTagKey)
	cmdr.Registry:RegisterType("chatTagKeys", cmdr.Util.MakeListableType(chatTagKey))
end

return ChatTagCmdrUtils