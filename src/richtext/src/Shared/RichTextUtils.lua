--!strict
--[=[
	Utility methods to work with Rich text

	@class RichTextUtils
]=]

local RichTextUtils = {}

--[=[
	Sanitizes the rich text string
	@param text string
	@return string
]=]
function RichTextUtils.sanitizeRichText(text: string): string
	assert(type(text) == "string", "Bad text")

	--stylua: ignore
	return (text:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub("\"", "&quot;")
		:gsub("'", "&apos;"))
end

--[=[
	Unescapes any rich text.
	@param text string
	@return string
]=]
function RichTextUtils.removeRichTextEncoding(text: string): string
	assert(type(text) == "string", "Bad text")

	--stylua: ignore
	return (text:gsub("<[^>]+>", "")
		:gsub("&lt;", "<")
		:gsub("&gt;", ">")
		:gsub("&quot;", "\"")
		:gsub("&apos;", "'")
		:gsub("&amp;", "&"))
end

return RichTextUtils