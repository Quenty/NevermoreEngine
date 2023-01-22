--[=[
	Utility methods to query policies for players from [PolicyService].

	@class PolicyServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local PolicyService = game:GetService("PolicyService")

local Promise = require("Promise")

local PolicyServiceUtils = {}

--[=[
	Promises policy info for players.

	@param player Player
	@return table
]=]
function PolicyServiceUtils.promisePolicyInfoForPlayer(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Promise.spawn(function(resolve, reject)
		local policies
		local ok, err = pcall(function()
			policies = PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if not ok then
			return reject(err)
		end

		if type(policies) ~= "table" then
			return reject("Failed to get policies for player")
		end

		return resolve(policies)
	end)
end

--[=[
	Returns true if you can reference Twitter

	@param policyInfo PolicyInfo
	@return boolean
]=]
function PolicyServiceUtils.canReferenceTwitter(policyInfo)
	assert(type(policyInfo) == "table", "Bad policyInfo")

	return PolicyServiceUtils.canReferenceSocialMedia(policyInfo, "Twitch")
end

--[=[
	Returns true if you can reference Twitch

	@param policyInfo PolicyInfo
	@return boolean
]=]
function PolicyServiceUtils.canReferenceTwitch(policyInfo)
	assert(type(policyInfo) == "table", "Bad policyInfo")

	return PolicyServiceUtils.canReferenceSocialMedia(policyInfo, "Twitch")
end


--[=[
	Returns true if you can reference Discord

	@param policyInfo PolicyInfo
	@return boolean
]=]
function PolicyServiceUtils.canReferenceDiscord(policyInfo)
	assert(type(policyInfo) == "table", "Bad policyInfo")

	return PolicyServiceUtils.canReferenceSocialMedia(policyInfo, "Discord")
end

--[=[
	Returns true if you can reference Facebook

	@param policyInfo PolicyInfo
	@return boolean
]=]
function PolicyServiceUtils.canReferenceFacebook(policyInfo)
	assert(type(policyInfo) == "table", "Bad policyInfo")

	return PolicyServiceUtils.canReferenceSocialMedia(policyInfo, "Facebook")
end

--[=[
	Returns true if you can reference YouTube

	@param policyInfo PolicyInfo
	@return boolean
]=]
function PolicyServiceUtils.canReferenceYouTube(policyInfo)
	assert(type(policyInfo) == "table", "Bad policyInfo")

	return PolicyServiceUtils.canReferenceSocialMedia(policyInfo, "YouTube")
end

--[=[
	Returns true if you can reference a specific social media title

	@param policyInfo PolicyInfo
	@param socialInfoName string
	@return boolean
]=]
function PolicyServiceUtils.canReferenceSocialMedia(policyInfo, socialInfoName)
	assert(type(policyInfo) == "table", "Bad policyInfo")
	assert(type(socialInfoName) == "string", "Bad socialInfoName")

	if not (type(policyInfo.AllowedExternalLinkReferences) == "table") then
		warn("[PolicyServiceUtils.canReferenceDiscord] - Bad policyInfo")
		return false
	end

	for _, item in pairs(policyInfo.AllowedExternalLinkReferences) do
		if item == socialInfoName then
			return true
		end
	end

	return false
end

return PolicyServiceUtils