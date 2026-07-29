--!strict
--[[
	@class TranslationKeyUtils.spec.lua

	Covers [TranslationKeyUtils.getTranslationKey].

	These vectors are frozen, not merely current. The derived key is a persisted identifier: it is
	baked into every locale table a consumer has already built, into the cloud localization table,
	and into any key a game replicates. Rederiving it does not migrate that data -- it unbinds it,
	and every affected line silently falls back to its source language.

	This happened. #737 made spaced text camelCase ("Play Now" -> "playNow" rather than "playnow")
	and shipped as a patch, which unbound 6,849 of egg-hunt-2026's 8,585 built entries. Nothing
	failed, nothing warned; the game just rendered English.

	So a change here is a breaking data-format change. It needs a major version and a migration that
	re-keys every consumer's tables, not a fix. If you only want prettier keys, that is not a reason.
]]

local require = require(script.Parent.loader).load(script)

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

	it("collapses spaces instead of treating them as word boundaries", function()
		expect(TranslationKeyUtils.getTranslationKey("button", "Play Now")).toBe("button.playnow")
		expect(TranslationKeyUtils.getTranslationKey("hint", "Press E")).toBe("hint.presse")
	end)

	it("camelCases underscore-separated text", function()
		expect(TranslationKeyUtils.getTranslationKey("x", "hello_world")).toBe("x.helloWorld")
	end)

	it("drops punctuation", function()
		expect(TranslationKeyUtils.getTranslationKey("line", "That's amore!")).toBe("line.thatsamore")
	end)

	it("caps the derived key at 20 characters of the whitespace-stripped source", function()
		expect(TranslationKeyUtils.getTranslationKey("x", "abcdefghijklmnopqrstuvwxyz")).toBe("x.abcdefghijklmnopqrst")
		-- Whitespace is removed before the cap, so the cut lands 20 characters into the stripped
		-- text rather than 20 characters into a camelCased rendering of it.
		expect(TranslationKeyUtils.getTranslationKey("line", "Once upon a time long ago there was a king")).toBe(
			"line.onceuponatimelongago"
		)
	end)
end)
