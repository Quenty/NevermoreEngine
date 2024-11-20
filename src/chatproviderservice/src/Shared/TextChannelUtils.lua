--[=[
	Utility functions for querying text channels.
	@class TextChannelUtils
]=]

local require = require(script.Parent.loader).load(script)

local TextChatService = game:GetService("TextChatService")

local TextChannelUtils = {}

function TextChannelUtils.getDefaultTextChannel()
	return TextChannelUtils.getTextChannel("RBXGeneral")
end

function TextChannelUtils.getTextChannel(channelName: string)
	local channels = TextChannelUtils.getTextChannels()
	if not channels then
		return
	end

	return channels:FindFirstChild(channelName)
end

function TextChannelUtils.getTextChannels()
	return TextChatService:FindFirstChild("TextChannels")
end

return TextChannelUtils