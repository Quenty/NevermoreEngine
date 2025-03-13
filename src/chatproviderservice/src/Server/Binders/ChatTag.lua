--[=[
	@class ChatTag
]=]

local require = require(script.Parent.loader).load(script)

local ChatTagBase = require("ChatTagBase")
local Binder = require("Binder")

local ChatTag = setmetatable({}, ChatTagBase)
ChatTag.ClassName = "ChatTag"
ChatTag.__index = ChatTag

function ChatTag.new(folder: Folder, serviceBag)
	local self = setmetatable(ChatTagBase.new(folder), ChatTag)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerDataStoreService = self._serviceBag:GetService(require("PlayerDataStoreService"))

	self:_loadData()

	return self
end

function ChatTag:_getPlayer(): Player
	return self._obj:FindFirstAncestorWhichIsA("Player")
end

function ChatTag:_loadData()
	local player = self:_getPlayer()
	if not player then
		return
	end

	local tagKey = self.ChatTagKey.Value
	if not tagKey then
		return
	end

	self._maid:GivePromise(self._playerDataStoreService:PromiseDataStore(player))
		:Then(function(dataStore)
			return dataStore:GetSubStore("chatTags"):GetSubStore(tagKey)
		end)
		:Then(function(dataStore)
			return dataStore:Load("UserDisabled", false)
				:Then(function(userDisabled)
					self.UserDisabled.Value = userDisabled

					self._maid:GiveTask(dataStore:StoreOnValueChange("UserDisabled", self.UserDisabled))
				end)
		end)
end

return Binder.new("ChatTag", ChatTag)