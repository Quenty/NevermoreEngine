--[=[
	@class ChatTag
]=]

local require = require(script.Parent.loader).load(script)

local ChatTagBase = require("ChatTagBase")
local Binder = require("Binder")

local ChatTag = setmetatable({}, ChatTagBase)
ChatTag.ClassName = "ChatTag"
ChatTag.__index = ChatTag

function ChatTag.new(folder, serviceBag)
	local self = setmetatable(ChatTagBase.new(folder), ChatTag)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Binder.new("ChatTag", ChatTag)