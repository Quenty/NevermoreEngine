--!strict
--[[
	@class PluralCategoryUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PluralCategoryUtils = require("PluralCategoryUtils")

local describe = Jest.Globals.describe
local it = Jest.Globals.it

describe("PluralCategoryUtils.getPluralCategory", function()
	-- CLDR's samples for each category, as fraction digits written ("" for a whole number)
	local SAMPLES: { [string]: { { any } } } = {
		en = { { 1, "", "one" }, { 0, "", "other" }, { 2, "", "other" }, { 1, "0", "other" }, { 1.5, "5", "other" } },
		de = { { 1, "", "one" }, { 2, "", "other" }, { 1, "0", "other" } },
		es = { { 1, "", "one" }, { 1, "0", "one" }, { 2, "", "other" }, { 1000000, "", "many" }, { 0.5, "5", "other" } },
		fr = { { 0, "", "one" }, { 1, "", "one" }, { 1.5, "5", "one" }, { 2, "", "other" }, { 1000000, "", "many" } },
		pt = { { 0, "", "one" }, { 1.5, "5", "one" }, { 2, "", "other" }, { 2000000, "", "many" } },
		it = { { 1, "", "one" }, { 1, "0", "other" }, { 2, "", "other" }, { 1000000, "", "many" } },
		ru = {
			{ 1, "", "one" },
			{ 21, "", "one" },
			{ 2, "", "few" },
			{ 24, "", "few" },
			{ 0, "", "many" },
			{ 5, "", "many" },
			{ 11, "", "many" },
			{ 12, "", "many" },
			{ 1.5, "5", "other" },
		},
		pl = {
			{ 1, "", "one" },
			{ 2, "", "few" },
			{ 22, "", "few" },
			{ 0, "", "many" },
			{ 5, "", "many" },
			{ 21, "", "many" },
			{ 12, "", "many" },
			{ 1.5, "5", "other" },
		},
		tr = { { 1, "", "one" }, { 2, "", "other" }, { 1, "0", "one" } },
		vi = { { 0, "", "one" }, { 1, "", "one" }, { 0.5, "5", "one" }, { 2, "", "other" } },
		ar = {
			{ 0, "", "zero" },
			{ 1, "", "one" },
			{ 2, "", "two" },
			{ 3, "", "few" },
			{ 103, "", "few" },
			{ 11, "", "many" },
			{ 99, "", "many" },
			{ 100, "", "other" },
			{ 102, "", "other" },
			{ 1.5, "5", "other" },
		},
		id = { { 1, "", "other" } },
		th = { { 1, "", "other" } },
		ja = { { 1, "", "other" } },
		ko = { { 1, "", "other" } },
		["zh-cn"] = { { 1, "", "other" } },
		["zh-tw"] = { { 1, "", "other" } },
	}

	it("follows CLDR's rule for every shipped language", function()
		for locale, samples in SAMPLES do
			for _, sample in samples do
				local fraction = if sample[2] == "" then nil else sample[2]
				local category = PluralCategoryUtils.getPluralCategory(locale, sample[1], fraction)
				if category ~= sample[3] then
					error(string.format("%s %s: expected %s, got %s", locale, tostring(sample[1]), sample[3], category))
				end
			end
		end
	end)
end)
