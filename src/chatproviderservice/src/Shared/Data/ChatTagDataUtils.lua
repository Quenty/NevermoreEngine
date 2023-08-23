--[=[
	@class ChatTagDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local LocalizedTextUtils = require("LocalizedTextUtils")

local ChatTagDataUtils = {}

--[=[
	Creates new chat tag data

	@param data ChatTagData
	@return ChatTagData
]=]
function ChatTagDataUtils.createChatTagData(data)
	assert(ChatTagDataUtils.isChatTagData(data), "Bad data")

	return data
end

--[=[
	Returns true if a valid list

	@param data any
	@return boolean
	@return string -- reason why
]=]
function ChatTagDataUtils.isChatTagDataList(data)
	if type(data) ~= "table" then
		return false, "not a table"
	end

	for _, item in pairs(data) do
		if not ChatTagDataUtils.isChatTagData(item) then
			return false, "Bad tag data"
		end
	end

	return true
end

--[=[
	Returns if chat tag data

	@param data any
	@return boolean
]=]
function ChatTagDataUtils.isChatTagData(data)
	return type(data) == "table"
		and type(data.TagText) == "string"
		and type(data.TagPriority) == "number"
		and (LocalizedTextUtils.isLocalizedText(data.TagLocalizedText) or data.TagLocalizedText == nil)
		and typeof(data.TagColor) == "Color3"
end

return ChatTagDataUtils