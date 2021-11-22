---
-- @module GroupUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local GroupService = game:GetService("GroupService")

local Promise = require("Promise")

local GroupUtils = {}

function GroupUtils.promiseRankInGroup(player, groupId)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(groupId) == "number", "Bad groupId")

	return Promise.spawn(function(resolve, reject)
		local rank = nil
		local ok, err = pcall(function()
			rank = player:GetRankInGroup(groupId)
		end)

		if not ok then
			return reject(err)
		end

		if type(rank) ~= "number" then
			return reject("Rank is not a number")
		end

		return resolve(rank)
	end)
end

function GroupUtils.promiseRoleInGroup(player, groupId)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(groupId) == "number", "Bad groupId")

	return Promise.spawn(function(resolve, reject)
		local role = nil
		local ok, err = pcall(function()
			role = player:GetRoleInGroup(groupId)
		end)

		if not ok then
			return reject(err)
		end

		if type(role) ~= "string" then
			return reject("Role is not a string")
		end

		return resolve(role)
	end)
end

function GroupUtils.promiseGroupInfo(groupId)
	assert(groupId, "Bad groupId")

	return Promise.spawn(function(resolve, reject)
		local groupInfo = nil
		local ok, err = pcall(function()
			groupInfo = GroupService:GetGroupInfoAsync(groupId)
		end)

		if not ok then
			return reject(err)
		end

		if type(groupInfo) ~= "table" then
			return reject("Rank is not a number")
		end

		return resolve(groupInfo)
	end)
end

function GroupUtils.promiseGroupRoleInfo(groupId, rankId)
	assert(groupId, "Bad groupId")
	assert(rankId, "Bad rankId")

	return GroupUtils.promiseGroupInfo(groupId)
		:Then(function(groupInfo)
			if type(groupInfo.Roles) ~= "table" then
				return Promise.rejected("No Roles table")
			end

			for _, rankInfo in pairs(groupInfo.Roles) do
				if rankInfo.Rank == rankId then
					return rankInfo
				end
			end

			return Promise.rejected("No rank with given id")
		end)
end

return GroupUtils