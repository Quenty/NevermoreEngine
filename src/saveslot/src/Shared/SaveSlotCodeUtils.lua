--!strict
--[=[
	Generates human-sanity-checkable share codes for exported save slots, and defines the injectable
	generator a game overrides via [SaveSlotService.SetCodeGenerator]. The default format,
	`<date>-<state>-<user>-<token>` (e.g. `20260723-world3-jonnen-4f7k2q1a`), is recognizable on
	copy/paste -- you can eyeball the date, slot, and owner -- while the random token keeps it
	collision-resistant. Codes are used as datastore keys, so every component is sanitized to a safe,
	length-capped lowercase slug.

	@class SaveSlotCodeUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local SaveSlotCodeUtils = {}

--[=[
	The information a code generator may fold into a code. Every field is optional -- a generator must
	degrade gracefully when, say, the player's user id cannot be resolved.

	@interface CodeGeneratorContext
	@within SaveSlotCodeUtils
	.userId number?
	.userName string?
	.slotName string?
	.slotIndex number?
]=]
export type CodeGeneratorContext = {
	userId: number?,
	userName: string?,
	slotName: string?,
	slotIndex: number?,
}

--[=[
	Produces a share code from the context. Injected per game via [SaveSlotService.SetCodeGenerator].

	@type CodeGenerator (CodeGeneratorContext) -> string
	@within SaveSlotCodeUtils
]=]
export type CodeGenerator = (CodeGeneratorContext) -> string

-- Lowercases to alphanumeric, caps the length, and never returns empty -- so every component is a
-- safe datastore-key slug.
local function slug(text: string, maxLength: number): string
	local cleaned = (string.gsub(string.lower(text), "[^a-z0-9]", ""))
	if #cleaned == 0 then
		return "x"
	end
	return string.sub(cleaned, 1, maxLength)
end

local function shortToken(): string
	return string.lower(string.sub((string.gsub(HttpService:GenerateGUID(false), "%-", "")), 1, 8))
end

--[=[
	The default share-code generator: `<date>-<state>-<user>-<token>`.

	@param context CodeGeneratorContext
	@return string
]=]
function SaveSlotCodeUtils.generateDefaultCode(context: CodeGeneratorContext): string
	local date = os.date("!%Y%m%d")
	local state = slug(context.slotName or (context.slotIndex and `slot{context.slotIndex}`) or "slot", 10)
	local user = slug(context.userName or (context.userId and tostring(context.userId)) or "anon", 12)
	return `{date}-{state}-{user}-{shortToken()}`
end

return SaveSlotCodeUtils
