--!strict
--[=[
	Progress replies for commands that yield.

	Cmdr prints nothing between dispatching a command and its body returning, so a command that
	spends seconds in a datastore retry ladder is indistinguishable from one that has hung. These
	replies fill that gap without adding a line to a command that finishes promptly.

	```lua
	local config = CmdrReplyUtils.createConfig()

	return CmdrReplyUtils.replyWhenSlow(config, context, self:_promiseWork(userId), `{userId}: still working...`)
		:Then(function(line) ... end)
	```

	@class CmdrReplyUtils
]=]

local require = require(script.Parent.loader).load(script)

local CmdrTypes = require("CmdrTypes")
local Promise = require("Promise")

local CmdrReplyUtils = {}

--[=[
	@interface CmdrReplyConfig
	.slowReplySeconds number -- How long work is given to finish before the executor is told it is still running
	.progressColor Color3 -- Color of the progress reply
	@within CmdrReplyUtils
]=]
export type CmdrReplyConfig = {
	slowReplySeconds: number,
	progressColor: Color3,
}

export type PartialCmdrReplyConfig = {
	slowReplySeconds: number?,
	progressColor: Color3?,
}

--[=[
	Creates a new reply config.

	The default threshold is long enough that a command which completes promptly stays silent, and
	the default color is muted so progress chatter does not compete with the results printed after
	it.

	@param config table? -- Optional table with overrides
	@return CmdrReplyConfig
]=]
function CmdrReplyUtils.createConfig(config: PartialCmdrReplyConfig?): CmdrReplyConfig
	local partial: PartialCmdrReplyConfig = config or {}

	return {
		slowReplySeconds = partial.slowReplySeconds or 0.5,
		progressColor = partial.progressColor or Color3.fromRGB(150, 150, 150),
	}
end

--[=[
	Returns whether an object is a reply config.

	@param config any
	@return boolean
]=]
function CmdrReplyUtils.isCmdrReplyConfig(config: any): boolean
	return type(config) == "table"
		and type(config.slowReplySeconds) == "number"
		and typeof(config.progressColor) == "Color3"
end

--[=[
	Replies `text` to the executor if `promise` is still running `slowReplySeconds` from now, and
	says nothing at all if it settles first.

	Returns the promise it was given, so it drops into an existing chain.

	@param config CmdrReplyConfig
	@param context CommandContext
	@param promise Promise<T...>
	@param text string
	@return Promise<T...> -- the promise that was passed in
]=]
function CmdrReplyUtils.replyWhenSlow<T...>(
	config: CmdrReplyConfig,
	context: CmdrTypes.CommandContext,
	promise: Promise.Promise<T...>,
	text: string
): Promise.Promise<T...>
	assert(CmdrReplyUtils.isCmdrReplyConfig(config), "Bad config")
	assert(context, "No context")
	assert(type(text) == "string", "Bad text")

	-- Flagged rather than cancelled. `task.cancel` against a thread that has already run errors, and
	-- an error raised out of the scheduler is not the command's to catch -- it surfaces as an
	-- uncaught error instead. A thread left to expire on its own costs one dead frame.
	local isSettled = false

	task.delay(config.slowReplySeconds, function()
		if isSettled then
			return
		end

		context:Reply(text, config.progressColor)
	end)

	-- Deliberately not returned. Finally() resolves its derived promise even when the source rejects,
	-- so handing that one back would report every failed target as a success.
	promise:Finally(function()
		isSettled = true
	end)

	return promise
end

return CmdrReplyUtils
