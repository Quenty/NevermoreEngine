--!strict
--[=[
	@class ChatTagClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local ChatTagBase = require("ChatTagBase")
local ServiceBag = require("ServiceBag")

local ChatTagClient = setmetatable({}, ChatTagBase)
ChatTagClient.ClassName = "ChatTagClient"
ChatTagClient.__index = ChatTagClient

export type ChatTagClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = ChatTagClient })
)) & ChatTagBase.ChatTagBase

function ChatTagClient.new(folder: Folder, serviceBag: ServiceBag.ServiceBag): ChatTagClient
	local self: ChatTagClient = setmetatable(ChatTagBase.new(folder) :: any, ChatTagClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("ChatTag", ChatTagClient :: any) :: Binder.Binder<ChatTagClient>
