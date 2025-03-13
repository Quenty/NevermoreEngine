--[=[
	@class ChatTagClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local ChatTagBase = require("ChatTagBase")

local ChatTagClient = setmetatable({}, ChatTagBase)
ChatTagClient.ClassName = "ChatTagClient"
ChatTagClient.__index = ChatTagClient

function ChatTagClient.new(folder: Folder, serviceBag)
	local self = setmetatable(ChatTagBase.new(folder), ChatTagClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("ChatTag", ChatTagClient)