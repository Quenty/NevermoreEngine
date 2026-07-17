--!nonstrict
--[[
	@class TranslationKeyUtils.spec.lua

	Covers [TranslationKeyUtils.getTranslationKey]. Spaced and underscore-separated
	source text both camelCase consistently ("Play Now" / "hello_world" ->
	"playNow" / "helloWorld"), and the derived key is capped at 20 characters.
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local TranslationKeyUtils = require("TranslationKeyUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TranslationKeyUtils.getTranslationKey", function()
	it("joins the prefix and the derived key with a dot", function()
		expect(TranslationKeyUtils.getTranslationKey("button", "Jump")).toBe("button.jump")
		expect(TranslationKeyUtils.getTranslationKey("menu", "Settings")).toBe("menu.settings")
	end)

	it("camelCases spaced text (spaces are treated as word boundaries)", function()
		expect(TranslationKeyUtils.getTranslationKey("button", "Play Now")).toBe("button.playNow")
		expect(TranslationKeyUtils.getTranslationKey("hint", "Press E")).toBe("hint.pressE")
	end)

	it("camelCases underscore-separated text", function()
		expect(TranslationKeyUtils.getTranslationKey("x", "hello_world")).toBe("x.helloWorld")
	end)

	it("truncates the derived key to a maximum length", function()
		local key = TranslationKeyUtils.getTranslationKey("x", "abcdefghijklmnopqrstuvwxyz")
		-- Everything after the "x." prefix is capped at 20 characters.
		expect(key).toBe("x.abcdefghijklmnopqrst")
	end)
end)
