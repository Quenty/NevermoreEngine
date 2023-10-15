--[=[
	@class EloMatchResultUtils
]=]

local require = require(script.Parent.loader).load(script)

local EloMatchResult = require("EloMatchResult")

local EloMatchResultUtils = {}

function EloMatchResultUtils.isEloMatchResult(matchResult)
	return matchResult == EloMatchResult.PLAYER_ONE_WIN
		or matchResult == EloMatchResult.PLAYER_TWO_WIN
		or matchResult == EloMatchResult.DRAW
end

function EloMatchResultUtils.isEloMatchResultList(eloMatchResultList)
	if type(eloMatchResultList) ~= "table" then
		return false
	end

	for _, eloMatchResult in pairs(eloMatchResultList) do
		if not EloMatchResultUtils.isEloMatchResult(eloMatchResult) then
			return false
		end
	end

	return true
end

return EloMatchResultUtils