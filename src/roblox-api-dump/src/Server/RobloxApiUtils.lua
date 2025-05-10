--!strict
--[=[
	@class RobloxApiUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpPromise = require("HttpPromise")
local Promise = require("Promise")

local API_DUMP_URL = "https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Watch/roblox/API-Dump.json"

local RobloxApiUtils = {}

--[=[
	Retrieves the raw API dump from the web.
	@return Promise<table>
]=]
function RobloxApiUtils.promiseDump(): Promise.Promise<any>
	return HttpPromise.json(API_DUMP_URL)
end

return RobloxApiUtils