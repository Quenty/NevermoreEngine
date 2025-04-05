--!strict
--[=[
	@class EloMatchResultUtils
]=]

local require = require(script.Parent.loader).load(script)

local EloMatchResult = require("EloMatchResult")

local EloMatchResultUtils = {}

--[=[
	Checks if the given match result is a valid EloMatchResult.

	@param matchResult any
	@return boolean
]=]
function EloMatchResultUtils.isEloMatchResult(matchResult: any): boolean
	return matchResult == EloMatchResult.PLAYER_ONE_WIN
		or matchResult == EloMatchResult.PLAYER_TWO_WIN
		or matchResult == EloMatchResult.DRAW
end

--[=[
	Checks if the given match result is a valid EloMatchResult list

	@param eloMatchResultList any
	@return boolean
]=]
function EloMatchResultUtils.isEloMatchResultList(eloMatchResultList: {number }): boolean
	if type(eloMatchResultList) ~= "table" then
		return false
	end

	for _, eloMatchResult in eloMatchResultList do
		if not EloMatchResultUtils.isEloMatchResult(eloMatchResult) then
			return false
		end
	end

	return true
end

return EloMatchResultUtils