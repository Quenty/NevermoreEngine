--!strict
--[=[
	@class ChatTag
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local ChatTagBase = require("ChatTagBase")
local ServiceBag = require("ServiceBag")

local ChatTag = setmetatable({}, ChatTagBase)
ChatTag.ClassName = "ChatTag"
ChatTag.__index = ChatTag

export type ChatTag =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_playerDataStoreService: any, -- PlayerDataStoreService (GetService returns the module type, not the instance type)
		},
		{} :: typeof({ __index = ChatTag })
	))
	& ChatTagBase.ChatTagBase

function ChatTag.new(folder: Folder, serviceBag: ServiceBag.ServiceBag): ChatTag
	local self: ChatTag = setmetatable(ChatTagBase.new(folder) :: any, ChatTag)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerDataStoreService = self._serviceBag:GetService(require("PlayerDataStoreService"))

	self:_loadData()

	return self
end

function ChatTag._getPlayer(self: ChatTag): Player?
	return self._obj:FindFirstAncestorWhichIsA("Player") :: Player?
end

function ChatTag._loadData(self: ChatTag)
	local player = self:_getPlayer()
	if not player then
		return
	end

	local tagKey = self.ChatTagKey.Value
	if tagKey == "" then
		return
	end

	self._maid
		:GivePromise(self._playerDataStoreService:PromiseDataStore(player))
		:Then(function(dataStore)
			return dataStore:GetSubStore("chatTags"):GetSubStore(tagKey)
		end)
		:Then(function(dataStore)
			return dataStore:Load("UserDisabled", false):Then(function(userDisabled)
				self.UserDisabled.Value = userDisabled

				self._maid:GiveTask(dataStore:StoreOnValueChange("UserDisabled", self.UserDisabled))
			end)
		end)
end

return Binder.new("ChatTag", ChatTag :: any) :: Binder.Binder<ChatTag>
