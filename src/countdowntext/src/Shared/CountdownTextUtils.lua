--!strict
--[=[
	Utility functions to format countdowns in-game

	@class CountdownTextUtils
]=]

local CountdownTextUtils = {}

--[=[
	Formats countdown text

	@param seconds number
	@param whenAtZeroText string?
	@return string
]=]
function CountdownTextUtils.formatCountdown(seconds: number, whenAtZeroText: string?): string
	assert(type(seconds) == "number", "Bad seconds")
	assert(type(whenAtZeroText) == "string" or whenAtZeroText == nil, "Bad whenAtZeroText")

	if seconds < 0 then
		return whenAtZeroText or "0"
	end

	-- less than 1 minute
	if seconds <= 60 then
		return string.format("%d", seconds)
	end

	-- less than 1 hour
	if seconds <= 60*60 then
		local hours = math.floor(seconds / 60)
		return string.format("%0d:%02d", hours, seconds % 60)
	end

	local days = math.floor(seconds / 60 / 60 / 24)
	local hours = math.floor(seconds / 60 / 60) % 24
	local minutes = math.floor(seconds / 60) % 60

	if days == 0 then
		return string.format("%d:%02d:%02d",
			hours,
			minutes,
			seconds % 60)
	elseif days == 1 then
		-- People would be confused about "1 day 2:15:00"
		-- So show 47:15:00
		hours = math.floor(seconds / 60 / 60) % 48

		return string.format("%d:%02d:%02d",
			hours,
			minutes,
			seconds % 60)
	else
		-- TODO: Localize this "days" part?

		return string.format("%d days %d:%02d:%02d",
			days,
			hours,
			minutes,
			seconds % 60)
	end
end

return CountdownTextUtils