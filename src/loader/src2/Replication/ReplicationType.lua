--[=[
	Different replication types we can be in.

	@class ReplicationType
]=]

local Utils = require(script.Parent.Parent.Utils)

return Utils.readonly({
	CLIENT = "client";
	SERVER = "server";
	SHARED = "shared";
})