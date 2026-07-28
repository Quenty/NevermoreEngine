--!strict
--[=[
	Wire constants for the observable relay used by [Remoting].

	@class RemotingObservableConstants
	@private
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	--[[
		Appended to a member name to get the reserved member the relay talks over. A single
		RemoteEvent is full duplex, so one reserved member carries both directions.
	]]
	RESERVED_MEMBER_SUFFIX = "__Observe" :: "__Observe",

	-- Client to server
	OPCODE_SUBSCRIBE = 1,
	OPCODE_UNSUBSCRIBE = 2,

	-- Server to client
	OPCODE_FIRE = 3,
	OPCODE_COMPLETE = 4,
	OPCODE_FAIL = 5,

	MAX_SUBSCRIPTION_KEY_LENGTH = 64,
	MAX_SUBSCRIPTIONS_PER_PLAYER = 64,
})
