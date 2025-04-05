--!strict
--[=[
	@class EloMatchResult
]=]

return table.freeze(setmetatable({
	PLAYER_ONE_WIN = 1;
	DRAW = 0.5;
	PLAYER_TWO_WIN = 0;
}, {
	__index = function()
		error("Bad index onto EloMatchResult")
	end;
}))