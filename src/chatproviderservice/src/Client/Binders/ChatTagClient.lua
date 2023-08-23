--[=[
	@class ChatTagClient
]=]

local require = require(script.Parent.loader).load(script)

local ChatTagBase = require("ChatTagBase")
local Binder = require("Binder")

local ChatTagClient = setmetatable({}, ChatTagBase)
ChatTagClient.ClassName = "ChatTagClient"
ChatTagClient.__index = ChatTagClient

function ChatTagClient.new(folder, serviceBag)
	local self = setmetatable(ChatTagBase.new(folder), ChatTagClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("ChatTag", ChatTagClient)