--!strict
--[=[
	The lua implementation of the fzy string matching algorithm. This algorithm
	is optimized for matching stuff on the terminal, but should serve well as a
	baseline search algorithm within a game too.

	See:
	* https://github.com/swarn/fzy-lua
	* https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md

	Modified from the initial code to fit this codebase. While this
	definitely messes with some naming which may have been better, it
	also keeps usage of this library consistent with other libraries.

	Notes:
	* A higher score is better than a lower score
	* Scoring time is `O(n*m)` where `n` is the length of the needle
	  and `m` is the length of the haystack.
	* Scoring memory is also `O(n*m)`
	* Should do quite well with small lists

	TODO: Support UTF8

	@class Fzy
]=]

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

local MAX_SCORE = math.huge
local MIN_SCORE = -math.huge

local Fzy = {}

--[=[
	Configuration for Fzy. See [Fzy.createConfig] for details. This affects scoring
	and how the matching is done.

	@interface FzyConfig
	.caseSensitive boolean
	.gapLeadingScore number
	.gapTrailingScore number
	.gapInnerScore number
	.consecutiveMatchScore number
	.slashMatchScore number
	.wordMatchScore number
	.capitalMatchScore number
	.dotMatchScore number
	.maxMatchLength number
	@within Fzy
]=]
export type FzyConfig = {
	caseSensitive: boolean,
	gapLeadingScore: number,
	gapTrailingScore: number,
	gapInnerScore: number,
	consecutiveMatchScore: number,
	slashMatchScore: number,
	wordMatchScore: number,
	capitalMatchScore: number,
	dotMatchScore: number,
	maxMatchLength: number,
}

--[=[
	Creates a new configuration for Fzy.

	@param config table
	@return FzyConfig
]=]
function Fzy.createConfig(config: any): FzyConfig
	assert(type(config) == "table" or config == nil, "Bad config")

	config = config or {}

	if config.caseSensitive == nil then
		config.caseSensitive = false
	elseif type(config.caseSensitive) ~= "boolean" then
		error("Bad config.caseSensitive")
	end

	-- These numbers are from the Fzy, algorithm but may be adjusted
	config.gapLeadingScore = config.gapLeadingScore or -0.005
	config.gapTrailingScore = config.gapTrailingScore or -0.005
	config.gapInnerScore = config.gapInnerScore or -0.01
	config.consecutiveMatchScore = config.consecutiveMatchScore or 1.0
	config.slashMatchScore = config.slashMatchScore or 0.9
	config.wordMatchScore = config.wordMatchScore or 0.8
	config.capitalMatchScore = config.capitalMatchScore or 0.7
	config.dotMatchScore = config.dotMatchScore or 0.6
	config.maxMatchLength = config.maxMatchLength or 1024

	return config
end

--[=[
	Returns true if it is a config

	@param config any
	@return boolean
]=]
function Fzy.isFzyConfig(config: any): boolean
	return type(config) == "table"
		and type(config.gapLeadingScore) == "number"
		and type(config.gapTrailingScore) == "number"
		and type(config.gapInnerScore) == "number"
		and type(config.consecutiveMatchScore) == "number"
		and type(config.slashMatchScore) == "number"
		and type(config.wordMatchScore) == "number"
		and type(config.capitalMatchScore) == "number"
		and type(config.dotMatchScore) == "number"
		and type(config.maxMatchLength) == "number"
		and type(config.caseSensitive) == "boolean"
end

--[=[
	Check if `needle` is a subsequence of the `haystack`.

	Usually called before [Fzy.score] or [Fzy.positions].

	@param config FzyConfig
	@param needle string
	@param haystack string
	@return boolean
]=]
function Fzy.hasMatch(config: FzyConfig, needle: string, haystack: string): boolean
	if not config.caseSensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	local j: number? = 1
	for i = 1, string.len(needle) do
		j = string.find(haystack, string.sub(needle, i, i), j, true)
		if not j then
			return false
		else
			j = j + 1
		end
	end

	return true
end

local function is_lower(c: string): boolean
	return string.match(c, "%l") ~= nil
end

local function is_upper(c: string): boolean
	return string.match(c, "%u") ~= nil
end

local function precomputeBonus(config: FzyConfig, haystack: string)
	local matchBonus = {}

	local last_char = "/"
	for i = 1, string.len(haystack) do
		local this_char = string.sub(haystack, i, i)
		if last_char == "/" or last_char == "\\" then
			matchBonus[i] = config.slashMatchScore
		elseif last_char == "-" or last_char == "_" or last_char == " " then
			matchBonus[i] = config.wordMatchScore
		elseif last_char == "." then
			matchBonus[i] = config.dotMatchScore
		elseif is_lower(last_char) and is_upper(this_char) then
			matchBonus[i] = config.capitalMatchScore
		else
			matchBonus[i] = 0
		end

		last_char = this_char
	end

	return matchBonus
end

local function compute(config: FzyConfig, needle: string, haystack: string, D: { { number } }, M)
	-- Note that the match bonuses must be computed before the arguments are
	-- converted to lowercase, since there are bonuses for camelCase.

	local matchBonus = precomputeBonus(config, haystack)
	local n = string.len(needle)
	local m = string.len(haystack)

	if not config.caseSensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	-- Because lua only grants access to chars through substring extraction,
	-- get all the characters from the haystack once now, to reuse below.
	local haystackChars = {}
	for i = 1, m do
		haystackChars[i] = string.sub(haystack, i, i)
	end

	for i = 1, n do
		D[i] = {}
		M[i] = {}

		local prevScore = MIN_SCORE
		local gapScore = i == n and config.gapTrailingScore or config.gapInnerScore
		local needle_char = string.sub(needle, i, i)

		for j = 1, m do
			if needle_char == haystackChars[j] then
				local score = MIN_SCORE
				if i == 1 then
					score = ((j - 1) * config.gapLeadingScore) + matchBonus[j]
				elseif j > 1 then
					local a = M[i - 1][j - 1] + matchBonus[j]
					local b = D[i - 1][j - 1] + config.consecutiveMatchScore
					score = math.max(a, b)
				end
				D[i][j] = score
				prevScore = math.max(score, prevScore + gapScore)
				M[i][j] = prevScore
			else
				D[i][j] = MIN_SCORE
				prevScore = prevScore + gapScore
				M[i][j] = prevScore
			end
		end
	end
end

--[=[
	Computes whether a needle or haystack are a perfect match or not

	@param config FzyConfig
	@param needle string -- must be a subequence of `haystack`, or the result is undefined.
	@param haystack string
	@return boolean
]=]
function Fzy.isPerfectMatch(config: FzyConfig, needle: string, haystack: string): boolean
	if config.caseSensitive then
		return needle == haystack
	else
		return string.lower(needle) == string.lower(haystack)
	end
end

--[=[
	Compute a matching score.

	@param config FzyConfig
	@param needle string -- must be a subequence of `haystack`, or the result is undefined.
	@param haystack string
	@return number -- higher scores indicate better matches. See also [Fzy.getMinScore] and [Fzy.getMaxScore].
]=]
function Fzy.score(config: FzyConfig, needle: string, haystack: string): number
	local n = string.len(needle)
	local m = string.len(haystack)

	if n == 0 or m == 0 or m > config.maxMatchLength or n > m then
		return MIN_SCORE
	elseif Fzy.isPerfectMatch(config, needle, haystack) then
		return MAX_SCORE
	else
		local D = {}
		local M = {}
		compute(config, needle, haystack, D, M)
		return M[n][m]
	end
end

--[=[
	Compute the locations where fzy matches a string.

	Determine where each character of the `needle` is matched to the `haystack`
	in the optimal match.

	@param config FzyConfig
	@param needle string -- must be a subequence of `haystack`, or the result is undefined.
	@param haystack string
	@return { int } -- indices, where `indices[n]` is the location of the `n`th character of `needle` in `haystack`.
	@return number -- the same matching score returned by `score`
]=]
function Fzy.positions(config: FzyConfig, needle: string, haystack: string): ({ number }, number)
	local n = string.len(needle)
	local m = string.len(haystack)

	if n == 0 or m == 0 or m > config.maxMatchLength or n > m then
		return {}, MIN_SCORE
	elseif Fzy.isPerfectMatch(config, needle, haystack) then
		local consecutive = {}
		for i = 1, n do
			consecutive[i] = i
		end
		return consecutive, MAX_SCORE
	end

	local D = {}
	local M = {}
	compute(config, needle, haystack, D, M)

	local positions = {}
	local match_required = false
	local j = m
	for i = n, 1, -1 do
		while j >= 1 do
			if D[i][j] ~= MIN_SCORE and (match_required or D[i][j] == M[i][j]) then
				match_required = (i ~= 1) and (j ~= 1) and (M[i][j] == D[i - 1][j - 1] + config.consecutiveMatchScore)
				positions[i] = j
				j = j - 1
				break
			else
				j = j - 1
			end
		end
	end

	return positions, M[n][m]
end

--[=[
	Apply [Fzy.hasMatch] and [Fzy.positions] to an array of haystacks.

	Returns an array with one entry per matching line in `haystacks`,
	each entry giving the index of the line in `haystacks` as well as
	the equivalent to the return value of `positions` for that line.

	@param config FzyConfig
	@param needle string
	@param haystacks { string }
	@return {{idx, positions, score}, ...}
]=]
function Fzy.filter(config: FzyConfig, needle: string, haystacks: { string }): { any }
	local result: { any } = {}

	for i, line in ipairs(haystacks) do
		if Fzy.hasMatch(config, needle, line) then
			local p, s = Fzy.positions(config, needle, line)
			table.insert(result, { i, p, s } :: { any })
		end
	end

	return result
end

--[=[
	The lowest value returned by `score`.

	In two special cases:
	 - an empty `needle`, or
	 - a `needle` or `haystack` larger than than [Fzy.getMaxLength],

	the [Fzy.score] function will return this exact value, which can be used as a
	sentinel. This is the lowest possible score.

	@return number
]=]
function Fzy.getMinScore(): number
	return MIN_SCORE
end

--[=[
	The score returned for exact matches. This is the highest possible score.

	@return number
]=]
function Fzy.getMaxScore(): number
	return MAX_SCORE
end

--[=[
	The maximum size for which `fzy` will evaluate scores.

	@param config FzyConfig
	@return number
]=]
function Fzy.getMaxLength(config: FzyConfig): number
	assert(Fzy.isFzyConfig(config), "Bad config")

	return config.maxMatchLength
end

--[=[
	The minimum score returned for normal matches.

	For matches that don't return [Fzy.getMinScore], their score will be greater
	than than this value.

	@param config FzyConfig
	@return number
]=]
function Fzy.getScoreFloor(config: FzyConfig): number
	assert(Fzy.isFzyConfig(config), "Bad config")

	return config.maxMatchLength * config.gapInnerScore
end

--[=[
	The maximum score for non-exact matches.

	For matches that don't return [Fzy.getMaxScore], their score will be less than
	this value.

	@param config FzyConfig
	@return number
]=]
function Fzy.getScoreCeiling(config: FzyConfig): number
	assert(Fzy.isFzyConfig(config), "Bad config")

	return config.maxMatchLength * config.consecutiveMatchScore
end

return Fzy