--- Utility methods for JSON
-- @module JSONUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local JSONUtils = {}

function JSONUtils.PromiseJSONDecode(str)
	if type(str) ~= "string" then
		return Promise.rejected(str)
	end

	return Promise.new(function(resolve, reject)
		local decoded
		local ok, err = pcall(function()
			decoded = HttpService:JSONDecode(str)
		end)

		if not ok then
			reject(err)
			return
		elseif decoded then
			resolve(decoded)
			return
		else
			reject("Failed to decode any value")
			return
		end
	end)
end

return JSONUtils