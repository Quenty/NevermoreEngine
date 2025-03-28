--[[
	Tests for fzy-lua

	See:
	https://github.com/swarn/fzy-lua
	https://github.com/jhawthorn/fzy

	@class Fzy.spec.lua
]]

--[[
The MIT License (MIT)

Copyright (c) 2020 Seth Warn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

local EPSILON = 0.000001

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Fzy = require("Fzy")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MIN_SCORE = Fzy.getMinScore()
local MAX_SCORE = Fzy.getMaxScore()

local function compareTables(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end

	for key, value in pairs(b) do
		if a[key] ~= value then
			return false
		end
	end

	return true
end

return function()
	local config = Fzy.createConfig({
		caseSensitive = false;
	})
	local caseSensitiveConfig = Fzy.createConfig({
		caseSensitive = true;
	})
	local MATCH_MAX_LENGTH = Fzy.getMaxLength(config)

	describe("matching", function()
		it("exact matches", function()
			expect(Fzy.hasMatch(config, "a", "a")).to.equal(true)
			expect(Fzy.hasMatch(caseSensitiveConfig, "a", "a")).to.equal(true)
			expect(Fzy.hasMatch(caseSensitiveConfig, "A", "A")).to.equal(true)
			expect(Fzy.hasMatch(config, "a.bb", "a.bb")).to.equal(true)
		end)
		it("handles special characters", function()
			expect(Fzy.hasMatch(config, "\\", "\\")).to.equal(true)
			expect(Fzy.hasMatch(config, "/", "/")).to.equal(true)
			expect(Fzy.hasMatch(config, "[", "[")).to.equal(true)
			expect(Fzy.hasMatch(config, "%", "%")).to.equal(true)
		end)
		it("ignores case by default", function()
			expect(Fzy.hasMatch(config, "AbB", "abb")).to.equal(true)
			expect(Fzy.hasMatch(config, "abb", "ABB")).to.equal(true)
		end)
		it("is case-sensitive when requested", function()
			expect(Fzy.hasMatch(caseSensitiveConfig, "AbB", "abb")).to.equal(false)
			expect(Fzy.hasMatch(caseSensitiveConfig, "abb", "ABB")).to.equal(false)
		end)
		it("partial matches", function()
			expect(Fzy.hasMatch(config, "a", "ab")).to.equal(true)
			expect(Fzy.hasMatch(config, "a", "ba")).to.equal(true)
			expect(Fzy.hasMatch(config, "aba", "baabbaab")).to.equal(true)
		end)
		it("with delimiters between", function()
			expect(Fzy.hasMatch(config, "abc", "a|b|c")).to.equal(true)
		end)
		it("with empty query", function()
			expect(Fzy.hasMatch(config, "", "")).to.equal(true)
			expect(Fzy.hasMatch(config, "", "a")).to.equal(true)
		end)
		it("rejects non-matches", function()
			expect(Fzy.hasMatch(config, "a", "")).to.equal(false)
			expect(Fzy.hasMatch(config, "a", "b")).to.equal(false)
			expect(Fzy.hasMatch(config, "aa", "a")).to.equal(false)
			expect(Fzy.hasMatch(config, "ba", "a")).to.equal(false)
			expect(Fzy.hasMatch(config, "ab", "a")).to.equal(false)
		end)
	end)

	describe("scoring", function()
		local function compare(queryStr, a, b)
			return Fzy.score(config, queryStr, a) > Fzy.score(config, queryStr, b)
		end

		it("prefers beginnings of words", function()
			expect(compare("amor", "app/models/order", "app/models/zrder")).to.equal(true)
			expect(compare("amor", "app models order", "app models zrder")).to.equal(true)
			expect(compare("amor", "appModelsOrder", "appModelsZrder")).to.equal(true)
			expect(compare("amor", "app\\models\\order", "app\\models\\zrder")).to.equal(true)
			expect(compare("a", ".a", "ba")).to.equal(true)
		end)
		it("prefers consecutive letters", function()
			expect(compare("amo", "app/models/foo", "app/m/foo")).to.equal(true)
			expect(compare("amo", "app/models/foo", "app/m/o")).to.equal(true)
			expect(compare("erf", "perfect", "terrific")).to.equal(true)
			expect(compare("abc", "*ab**c*", "*a*b*c*")).to.equal(true)
		end)
		it("prefers contiguous over letter following period", function()
			expect(compare("gemfil", "Gemfile", "Gemfile.lock")).to.equal(true)
		end)
		it("prefers shorter matches", function()
			expect(compare("abce", "abcdef", "abc de")).to.equal(true)
			expect(compare("abc", "    a b c ", " a  b  c ")).to.equal(true)
			expect(compare("abc", " a b c    ", " a  b  c ")).to.equal(true)
			expect(compare("aa", "*a*a*", "*a**a")).to.equal(true)
		end)
		it("prefers shorter candidates", function()
			expect(compare("test", "tests", "testing")).to.equal(true)
		end)
		it("prefers matches at the beginning", function()
			expect(compare("ab", "abbb", "babb")).to.equal(true)
			expect(compare("test", "testing", "/testing")).to.equal(true)
		end)
		it("returns the max score for exact matches", function()
			expect(Fzy.score(config, "abc", "abc")).to.equal(MAX_SCORE)
			expect(Fzy.score(config, "aBc", "abC")).to.equal(MAX_SCORE)
		end)
		it("returns the min score for empty queries", function()
			expect(Fzy.score(config, "", "")).to.equal(MIN_SCORE)
			expect(Fzy.score(config, "", "a")).to.equal(MIN_SCORE)
			expect(Fzy.score(config, "", "bb")).to.equal(MIN_SCORE)
		end)
		it("rewards matching slashes correctly", function()
			expect(compare("a", "*/a", "**a")).to.equal(true)
			expect(compare("a", "*\\a", "**a")).to.equal(true)
			expect(compare("a", "**/a", "*a")).to.equal(true)
			expect(compare("a", "**\\a", "*a")).to.equal(true)
			expect(compare("aa", "a/aa", "a/a")).to.equal(true)
		end)
		it("rewards matching camelCase correctly", function()
			expect(compare("a", "bA", "ba")).to.equal(true)
			expect(compare("a", "baA", "ba")).to.equal(true)
		end)
		it("scores in the prescribed bounds", function()
			local aaa = string.rep("a", MATCH_MAX_LENGTH)
			local aa = string.rep("a", MATCH_MAX_LENGTH - 1)
			expect(Fzy.getScoreCeiling(config) > Fzy.score(config, aa, aaa)).to.equal(true)
			local aba = "a" .. string.rep("b", MATCH_MAX_LENGTH - 2) .. "a"
			expect(Fzy.getScoreFloor(config) < Fzy.score(config, "aa", aba)).to.equal(true)
		end)
		it("ignores really long strings", function()
			local longstring = string.rep("a", MATCH_MAX_LENGTH + 1)
			expect(Fzy.score(config, "aa", longstring)).to.equal(MIN_SCORE)
			expect(Fzy.score(config, longstring, "aa")).to.equal(MIN_SCORE)
			expect(Fzy.score(config, longstring, longstring)).to.equal(MIN_SCORE)
		end)
		it("respects the case-sensitive argument", function()
			expect(Fzy.score(config, "aa", "bbbabab")).toBeCloseTo(Fzy.score(caseSensitiveConfig, "AA", "aaBABAB"), EPSILON)
			expect(Fzy.score(config, "bab", "bAacb")).toBeCloseTo(Fzy.score(caseSensitiveConfig, "bAb", "bAaBb"), EPSILON)
		end)
	end)

	describe("positioning", function()
		it("favors consecutive positions", function()
			expect(compareTables({1, 5, 6}, Fzy.positions(config, "amo", "app/models/foo"))).toBe(true)
		end)
		it("favors word beginnings", function()
			expect(compareTables({1, 5, 12, 13}, Fzy.positions(config, "amor", "app/models/order"))).toBe(true)
			expect(compareTables({3, 4}, Fzy.positions(config, "aa", "baAa"))).toBe(true)
			expect(compareTables({4}, Fzy.positions(config, "a", "ba.a"))).toBe(true)
		end)
		it("works when there are no bonuses", function()
			expect(compareTables({2, 4}, Fzy.positions(config, "as", "tags"))).toBe(true)
			expect(compareTables({3, 8}, Fzy.positions(config, "as", "examples.txt"))).toBe(true)
		end)
		it("favors smaller groupings of positions", function()
			expect(compareTables({3, 5, 7}, Fzy.positions(config, "abc", "a/a/b/c/c"))).toBe(true)
			expect(compareTables({3, 5, 7}, Fzy.positions(config, "abc", "a\\a\\b\\c\\c"))).toBe(true)
			expect(compareTables({4, 6, 8}, Fzy.positions(config, "abc", "*a*a*b*c*c"))).toBe(true)
			expect(compareTables({3, 5}, Fzy.positions(config, "ab", "caacbbc"))).toBe(true)
		end)
		it("handles exact matches", function()
			expect(compareTables({1, 2, 3}, Fzy.positions(config, "foo", "foo"))).toBe(true)
		end)
		it("ignores empty requests", function()
			expect(compareTables({}, Fzy.positions(config, "", ""))).toBe(true)
			expect(compareTables({}, Fzy.positions(config, "", "foo"))).toBe(true)
		end)
		it("ignores really long strings", function()
			local longstring = string.rep("a", MATCH_MAX_LENGTH + 1)
			expect(Fzy.score(config, "aa", longstring)).to.equal(MIN_SCORE)
			expect(Fzy.score(config, longstring, "aa")).to.equal(MIN_SCORE)
			expect(Fzy.score(config, longstring, longstring)).to.equal(MIN_SCORE)
		end)
		it("is case-sensitive when requested", function()
			expect(compareTables({2, 5}, Fzy.positions(caseSensitiveConfig, "AB", "aAabBb", true))).toBe(true)
		end)
		it("returns the same score as `score()`", function()
			local _, s = Fzy.positions(config, "ab", "aaabbb")
			expect(Fzy.score(config, "ab", "aaabbb")).to.equal(s)
			_, s = Fzy.positions(config, "aaa", "aaa")
			expect(Fzy.score(config, "aaa", "aaa")).to.equal(s)
			_, s = Fzy.positions(config, "", "aaa")
			expect(Fzy.score(config, "", "aaa")).to.equal(s)
		end)
	end)

	describe("filtering", function()
		it("repeats application of hasMatch and positions", function()

			-- compare the result of `filter` with repeated calls to `positions`
			local function check_filter(needle, haystacks, case)
				local result = Fzy.filter(config, needle, haystacks, case)
				local r = 0
				for i, line in ipairs(haystacks) do
					local match = Fzy.hasMatch(config, needle, line, case)
					if match then
						r = r + 1
						expect(i).to.equal(result[r][1])
						local p, s = Fzy.positions(config, needle, line, case)
						expect(compareTables(p, result[r][2])).to.equal(true)
						expect(s).to.equal(result[r][3])
					end
				end
				expect(#result).to.equal(r)
			end

			check_filter("a", {"a", "A", "aa", "b", ""})
			check_filter("a", {"a", "A", "aa", "b", ""}, true)
			check_filter("", {"a", "A", "aa", "b", ""})
			check_filter("a", {"b"})
			check_filter("a", {})
		end)
	end)
end