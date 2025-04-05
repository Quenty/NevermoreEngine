--!strict
--[=[
	Utility functions for querying text channels.
	@class TextChannelUtils
]=]

local TextChatService = game:GetService("TextChatService")

local TextChannelUtils = {}

function TextChannelUtils.getDefaultTextChannel(): TextChannel?
	return TextChannelUtils.getTextChannel("RBXGeneral")
end

function TextChannelUtils.getTextChannel(channelName: string): TextChannel?
	local channels = TextChannelUtils.getTextChannels()
	if channels == nil then
		return nil
	end

	local found = channels:FindFirstChild(channelName)
	if found == nil or not found:IsA("TextChannel") then
		return nil
	end

	return found
end

function TextChannelUtils.getTextChannels(): Instance?
	return TextChatService:FindFirstChild("TextChannels")
end

return TextChannelUtils