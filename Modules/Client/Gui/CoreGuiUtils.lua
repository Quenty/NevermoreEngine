---
-- @module CoreGuiUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local StarterGui = game:GetService("StarterGui")

local Promise = require("Promise")

local CoreGuiUtils = {}

function CoreGuiUtils.promiseRetrySetCore(tries, initialWaitTime, ...)
	assert(type(tries) == "number")

	local args = {...}
	local n = select("#", ...)

	return Promise.defer(function(resolve, reject)
		local waitTime = initialWaitTime

		local ok, err
		for _=1, tries do
			ok, err = CoreGuiUtils.tryToSetCore(unpack(args, 1, n))
			if ok then
				return resolve()
			else
				wait(waitTime)
				-- Exponential backoff
				waitTime = waitTime*2
			end
		end

		if not ok then
			return reject(err)
		end
	end)
end

function CoreGuiUtils.tryToSetCore(...)
	local args = {...}
	local n = select("#", ...)

	local ok, err = pcall(function()
		StarterGui:SetCore(unpack(args, 1, n))
	end)
	if not ok then
		return false, err
	end

	return true
end


return CoreGuiUtils