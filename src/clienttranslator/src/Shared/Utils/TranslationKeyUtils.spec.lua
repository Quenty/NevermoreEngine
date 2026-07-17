--!nonstrict
--[[
	@class TranslationKeyUtils.spec.lua

	Pins the *current* behavior of [TranslationKeyUtils.getTranslationKey].

	Note the space-collapse behavior below: because the implementation strips all
	whitespace *before* camel-casing, spaced source text loses its word boundaries
	("Play Now" -> "playnow"), while underscore-separated text keeps them
	("hello_world" -> "helloWorld"). That inconsistency is a bug; a follow-up commit
	fixes it and updates the expectations here.
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

	-- PIN (bug): whitespace is stripped before camel-casing, so spaced text collapses
	-- to all-lowercase instead of camelCase. The word boundary is lost with the space.
	it("collapses spaced text to lowercase (loses camelCase word boundaries)", function()
		expect(TranslationKeyUtils.getTranslationKey("button", "Play Now")).toBe("button.playnow")
		expect(TranslationKeyUtils.getTranslationKey("hint", "Press E")).toBe("hint.presse")
	end)

	-- PIN: underscores survive the whitespace strip, so they DO produce camelCase.
	it("camelCases underscore-separated text", function()
		expect(TranslationKeyUtils.getTranslationKey("x", "hello_world")).toBe("x.helloWorld")
	end)

	it("truncates the derived key to a maximum length", function()
		local key = TranslationKeyUtils.getTranslationKey("x", "abcdefghijklmnopqrstuvwxyz")
		-- Everything after the "x." prefix is capped at 20 characters.
		expect(key).toBe("x.abcdefghijklmnopqrst")
	end)
end)
