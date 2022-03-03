--[=[
	@class PlayerProductManagerConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_EVENT_NAME = "PlayerProductManagerRemoteEvent";

	-- Client -> Server
	NOTIFY_PROMPT_FINISHED = "NotifyPromptFinished";
	NOTIFY_GAMEPASS_FINISHED = "NotifyGamepassFinished";
})