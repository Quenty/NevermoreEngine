--- Provides a wrapper around HttpService with a promise API
-- @module HttpPromise

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpService = game:GetService("HttpService")

local Promise = require("Promise")

local HttpPromise = {}

---
-- @tparam {'PostAsync' | 'GetAsync'} methodName Method to send with
function HttpPromise.Method(methodName, url, ...)
	assert(type(methodName) == "string")
	assert(type(url) == "string")

	local Args = {...}

	return Promise.spawn(function(resolve, reject)
		local result

		local ok, err = pcall(function()
			result = HttpService[methodName](HttpService, url, unpack(Args))
		end)
		if not ok then
			warn(("[HttpPromise] - Failed request %q"):format(url), err)
			return reject(err)
		else
			return resolve(result)
		end
	end)
end

-- @tparam {string} url
function HttpPromise.Get(...)
	return HttpPromise.Method("GetAsync", ...)
end

function HttpPromise.Post(url, data, httpContentType, ...)
	if type(data) == "table" and httpContentType == Enum.HttpContentType.ApplicationJson then
		data = HttpService:JSONEncode(data)
	end
	return HttpPromise.Method("PostAsync", url, data, httpContentType, ...)
end

function HttpPromise.Json(...)
	return HttpPromise.Get(...):Then(function(result)

		-- Decode
		return Promise.new(function(resolve, reject)
			local decoded
			local ok, err = xpcall(function()
				decoded = HttpService:JSONDecode(result)
			end)

			if not ok then
				return reject(err)
			elseif decoded then
				return resolve(decoded)
			else
				return reject("decoded nothing")
			end
		end)
	end)
end

return HttpPromise
