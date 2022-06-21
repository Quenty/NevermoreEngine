--[=[
	@class TeleportServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local TeleportService = game:GetService("TeleportService")

local Promise = require("Promise")

local TeleportServiceUtils = {}

--[=[
	Wraps TeleportService:ReserveServer(placeId)
	@param placeId number
	@return Promise<string> -- Code
]=]
function TeleportServiceUtils.promiseReserveServer(placeId)
	assert(type(placeId) == "number", "Bad placeId")

	return Promise.spawn(function(resolve, reject)
		local accessCode
		local ok, err = pcall(function()
			accessCode = TeleportService:ReserveServer(placeId)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(accessCode)
	end)
end

--[=[
	Wraps TeleportService:PromiseTeleport(placeId, players, teleportOptions)
	@param placeId number
	@param players { Player }
	@param teleportOptions TeleportOptions
	@return Promise<string> -- Code
]=]
function TeleportServiceUtils.promiseTeleport(placeId, players, teleportOptions)
	assert(type(placeId) == "number", "Bad placeId")
	assert(type(players) == "table", "Bad players")
	assert(typeof(teleportOptions) == "Instance" and teleportOptions:IsA("TeleportOptions") or teleportOptions == nil, "Bad options")

	return Promise.spawn(function(resolve, reject)
		local teleportAsyncResult
		local ok, err = pcall(function()
			teleportAsyncResult = TeleportService:TeleportAsync(placeId, players, teleportOptions)
		end)
		if not ok then
			return reject(err)
		end

		return resolve(teleportAsyncResult)
	end)
end

return TeleportServiceUtils