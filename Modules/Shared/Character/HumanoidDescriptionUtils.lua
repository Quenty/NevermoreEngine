---
-- @module HumanoidDescriptionUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")
local InsertServiceUtils = require("InsertServiceUtils")
local PlayersServicePromises = require("PlayersServicePromises")

local HumanoidDescriptionUtils = {}

function HumanoidDescriptionUtils.promiseApplyDescription(humanoid, description)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"))
	assert(typeof(description) == "Instance" and description:IsA("HumanoidDescription"))

	return Promise.defer(function(resolve, reject)
		local ok, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)
		if not ok then
			reject(err)
			return
		end
		resolve()
	end)
end

function HumanoidDescriptionUtils.promiseApplyFromUserName(humanoid, userName)
	return HumanoidDescriptionUtils.promiseFromUserName(userName)
		:Then(function(description)
			return HumanoidDescriptionUtils.promiseApplyDescription(humanoid, description)
		end)
end

function HumanoidDescriptionUtils.promiseFromUserName(userName)
	return PlayersServicePromises.promiseUserIdFromName(userName)
		:Then(function(userId)
			return HumanoidDescriptionUtils.promiseFromUserId(userId)
		end)
end

function HumanoidDescriptionUtils.promiseFromUserId(userId)
	assert(type(userId) == "number")

	return Promise.defer(function(resolve, reject)
		local description = nil
		local ok, err = pcall(function()
			description = Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if not ok then
			reject(err)
			return
		end
		if not description then
			reject("API failed to return a description")
			return
		end
		assert(typeof(description) == "Instance")
		resolve(description)
	end)
end

function HumanoidDescriptionUtils.getAssetIdsFromString(assetString)
	if assetString == "" then
		return {}
	end

	local assetIds = {}
	for _, assetIdStr in pairs(string.split(assetString, ",")) do
		local num = tonumber(assetIdStr)
		if num then
			table.insert(assetIds, num)
		elseif assetIdStr ~= "" then
			warn(("[HumanoidDescriptionUtils/getAssetIdsFromString] - Failed to convert %q to assetId")
				:format(assetIdStr))
		end
	end

	return assetIds
end

function HumanoidDescriptionUtils.getAssetPromisesFromString(assetString)
	local promises = {}
	for _, assetId in pairs(HumanoidDescriptionUtils.getAssetIdsFromString(assetString)) do
		table.insert(promises, InsertServiceUtils.promiseAsset(assetId))
	end
	return promises
end

return HumanoidDescriptionUtils