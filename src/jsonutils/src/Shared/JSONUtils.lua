--- Utility methods for JSON
-- @module JSONUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local JSONUtils = {}

function JSONUtils.jsonDecode(str)
	if type(str) ~= "string" then
		return false, nil, "Not a string"
	end

	local decoded
	local ok, err = pcall(function()
		decoded = HttpService:JSONDecode(str)
	end)
	if not ok then
		return false, nil, err
	end

	return true, decoded
end

function JSONUtils.promiseJSONDecode(str)
	if type(str) ~= "string" then
		return Promise.rejected("Not a string")
	end

	return Promise.new(function(resolve, reject)
		local decoded
		local ok, err = pcall(function()
			decoded = HttpService:JSONDecode(str)
		end)

		if not ok then
			reject(err)
			return
		else
			resolve(decoded) -- May resolve to nil, but this is ok
			return
		end
	end)
end

return JSONUtils