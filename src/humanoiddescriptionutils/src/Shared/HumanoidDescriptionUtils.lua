--[=[
	Handles actions involving HumanoidDescription objects, including loading character appearance.
	@class HumanoidDescriptionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Promise = require("Promise")
local InsertServiceUtils = require("InsertServiceUtils")
local PlayersServicePromises = require("PlayersServicePromises")

local HumanoidDescriptionUtils = {}

--[=[
	Promises to apply a humaoid description
	@param humanoid Humanoid
	@param description HumanoidDescription
	@return Promise
]=]
function HumanoidDescriptionUtils.promiseApplyDescription(humanoid, description)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(description) == "Instance" and description:IsA("HumanoidDescription"), "Bad description")

	return Promise.spawn(function(resolve, reject)
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

--[=[
	Promises to apply a humaoid description reset call

	@param humanoid Humanoid
	@param description HumanoidDescription
	@param assetTypeVerification AssetTypeVerification
	@return Promise
]=]
function HumanoidDescriptionUtils.promiseApplyDescriptionReset(humanoid, description, assetTypeVerification)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")
	assert(typeof(description) == "Instance" and description:IsA("HumanoidDescription"), "Bad description")

	return Promise.spawn(function(resolve, reject)
		local ok, err = pcall(function()
			humanoid:ApplyDescriptionReset(description, assetTypeVerification)
		end)
		if not ok then
			reject(err)
			return
		end
		resolve()
	end)
end
--[=[
	Applies humanoid description from userName.
	@param humanoid Humanoid
	@param userName string
	@return Promise
]=]
function HumanoidDescriptionUtils.promiseApplyFromUserName(humanoid, userName)
	return HumanoidDescriptionUtils.promiseFromUserName(userName)
		:Then(function(description)
			return HumanoidDescriptionUtils.promiseApplyDescription(humanoid, description)
		end)
end

--[=[
	Retrieves a humanoid description from username
	@param userName string
	@return Promise<HumanoidDescription>
]=]
function HumanoidDescriptionUtils.promiseFromUserName(userName)
	return PlayersServicePromises.promiseUserIdFromName(userName)
		:Then(function(userId)
			return HumanoidDescriptionUtils.promiseFromUserId(userId)
		end)
end

--[=[
	Retrieves a humanoid description from userId
	@param userId number
	@return Promise<HumanoidDescription>
]=]
function HumanoidDescriptionUtils.promiseFromUserId(userId)
	assert(type(userId) == "number", "Bad userId")

	return Promise.spawn(function(resolve, reject)
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
		assert(typeof(description) == "Instance", "Bad description")
		resolve(description)
	end)
end

--[=[
	Retrieves the assetIds from an assetId, in the format that is known to us.
	@param assetString string -- A comma seperated value of asset ids which should be numbers
	@return { number }
]=]
function HumanoidDescriptionUtils.getAssetIdsFromString(assetString)
	if assetString == "" then
		return {}
	end

	local assetIds = {}
	for _, assetIdStr in string.split(assetString, ",") do
		local num = tonumber(assetIdStr)
		if num then
			table.insert(assetIds, num)
		elseif assetIdStr ~= "" then
			warn(
				string.format(
					"[HumanoidDescriptionUtils/getAssetIdsFromString] - Failed to convert %q to assetId",
					assetIdStr
				)
			)
		end
	end

	return assetIds
end

--[=[
	From stuff like [HumanoidDescription.HatAccessory].
	@param assetString string -- A comma seperated value of asset ids which should be numbers
	@return { Promise<Instance> }
]=]
function HumanoidDescriptionUtils.getAssetPromisesFromString(assetString)
	local promises = {}
	for _, assetId in HumanoidDescriptionUtils.getAssetIdsFromString(assetString) do
		table.insert(promises, InsertServiceUtils.promiseAsset(assetId))
	end
	return promises
end

return HumanoidDescriptionUtils