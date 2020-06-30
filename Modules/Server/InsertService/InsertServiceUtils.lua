---
-- @module InsertServiceUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local InsertService = game:GetService("InsertService")

local InsertServiceUtils = {}

function InsertServiceUtils.promiseAsset(assetId)
	assert(type(assetId) == "number")

	if assetId == 0 then
		return Promise.rejected()
	end

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = InsertService:LoadAsset(assetId)
		end)

		if not ok then
			return reject(err)
		end
		if typeof(result) ~= "Instance" then
			return reject("Result was not an instance")
		end

		resolve(result)
	end)
end
return InsertServiceUtils