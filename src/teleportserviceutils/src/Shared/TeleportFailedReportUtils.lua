--!strict
--[=[
	What the engine said about a client teleport, and what that means for what to do next.

	`TeleportInitFailed` reports outcomes rather than only failures -- `Success` and `IsTeleporting`
	arrive through the same event as the refusals do -- so a report is classified rather than assumed
	to be one. Two questions are worth asking of one: whether the hop is still running
	([TeleportFailedReportUtils.isInFlight]), and whether a refusal is worth another request
	([TeleportFailedReportUtils.shouldRetry]).

	All logic here is pure, so it is unit tested without a [Player] or a teleport.

	@class TeleportFailedReportUtils
]=]

local TeleportFailedReportUtils = {}

--[=[
	The whole of `TeleportInitFailed`, kept together so a caller decides on `result` instead of parsing
	`message`. Every rejection from [TeleportServiceUtils.promiseTeleportClientOnce] carries one, and it
	renders itself when a consumer only wants text.

	@interface TeleportReport
	.result Enum.TeleportResult
	.message string
	.placeId number -- the destination the report is about
	@within TeleportFailedReportUtils
]=]
export type TeleportReport = {
	result: Enum.TeleportResult,
	message: string,
	placeId: number,
}

--[=[
	A report that renders itself, so text-only consumers need not reach into it -- including
	PromiseRetryUtils, which tostrings whatever an attempt rejected with.

	@param placeId number
	@param result Enum.TeleportResult
	@param message string
	@return TeleportReport
]=]
function TeleportFailedReportUtils.new(placeId: number, result: Enum.TeleportResult, message: string): TeleportReport
	assert(type(placeId) == "number", "Bad placeId")
	assert(typeof(result) == "EnumItem", "Bad result")
	assert(type(message) == "string", "Bad message")

	return setmetatable({
		placeId = placeId,
		result = result,
		message = message,
	}, {
		__tostring = function(self: any): string
			return string.format("Teleport to place %d refused (%s): %s", self.placeId, self.result.Name, self.message)
		end,
	}) :: any
end

--[=[
	Whether a value is a report at all. A promise cancelled mid-teleport rejects with nothing rather
	than a refusal, so a consumer reading rejections has to tell the two apart before classifying.

	@param value any
	@return boolean
]=]
function TeleportFailedReportUtils.isReport(value: any): boolean
	return type(value) == "table" and typeof(value.result) == "EnumItem"
end

--[=[
	Whether a report means the hop is still happening rather than refused. `Success` is the engine
	confirming the request; `IsTeleporting` is it refusing a DUPLICATE while the original still runs,
	which is to say the one result that proves a request is alive. Neither is a failure, and answering
	either with another request is what stacks the concurrent teleports Roblox cannot hold.

	@param report TeleportReport
	@return boolean
]=]
function TeleportFailedReportUtils.isInFlight(report: TeleportReport): boolean
	assert(type(report) == "table", "Bad report")

	return report.result == Enum.TeleportResult.Success or report.result == Enum.TeleportResult.IsTeleporting
end

--[=[
	Whether a refusal is worth another request: the request is gone and the reason may not recur.
	False for the terminal refusals (`GameNotFound`, `Unauthorized`), which will refuse again however
	long we wait, and for `Flooded`, where another request is precisely what the engine is objecting
	to -- retrying either spends the player's time to reach the same refusal.

	@param report TeleportReport
	@return boolean
]=]
function TeleportFailedReportUtils.shouldRetry(report: TeleportReport): boolean
	assert(type(report) == "table", "Bad report")

	return report.result == Enum.TeleportResult.Failure
		or report.result == Enum.TeleportResult.GameFull
		or report.result == Enum.TeleportResult.GameEnded
end

return TeleportFailedReportUtils
