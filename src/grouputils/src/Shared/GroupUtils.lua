--!strict
--!nolint DeprecatedApi
--[=[
	Helpful functions involving Roblox groups.
	@class GroupUtils
]=]

local require = require(script.Parent.loader).load(script)

local GroupService = game:GetService("GroupService")

local Promise = require("Promise")

local GroupUtils = {}

type RoleTable = {
	Id: number,
	Name: string,
	Rank: number,
}
type RoleTableList = { RoleTable }
type GetRolesInGroupAsyncResult = {
	IsMember: boolean,
	Roles: RoleTableList,
}

local function _getHighestRoleTable(roleTableList: RoleTableList): RoleTable?
	local highestRank = 0
	local highestRankRoleTable: RoleTable? = nil
	for _, roleTable in roleTableList do
		if roleTable.Rank > highestRank then
			highestRank = roleTable.Rank
			highestRankRoleTable = roleTable
		end
	end
	return highestRankRoleTable
end

type GetGroupDictionary = {
	Name: string,
	Id: number,
	EmblemUrl: string,
	EmbelmId: number,
	Rank: number, -- deprecated, but probably won't annoy lint:luau
	Role: string, -- deprecated, but probably won't annoy lint:luau
	IsPrimary: boolean,
	IsInClan: boolean, -- deprecated, always false
}
type GetGroupsAsyncResult = { GetGroupDictionary }

local function _getRankAndRoleFallback(userId: number, groupId: number): (number, string?)
	-- euvin: i yoinked this from
	-- https://devforum.roblox.com/t/groupservicegetrolesingroupasync-is-not-enabled-yet-wiki-tells-me-to-use-it/4660969

	--? The GetRankInGroup method is deprecated and unstable now.
	--? https://devforum.roblox.com/t/excessive-rate-limits-when-checking-gamepasses-group-ranks/3549665
	local groups = GroupService:GetGroupsAsync(userId) :: GetGroupsAsyncResult

	for _, GroupInfo: GetGroupDictionary in groups do
		if GroupInfo.Id == groupId then
			return GroupInfo.Rank, GroupInfo.Role
		end
	end

	return 0, nil
end

--[=[
	Retrieves the rank of the player in the group.

	@param player Player
	@param groupId number
	@return Promise<number> -- Generally from 0 to 255
]=]
function GroupUtils.promiseRankInGroup(player: Player, groupId: number): Promise.Promise<number>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(groupId) == "number", "Bad groupId")

	return Promise.spawn(function(resolve, reject)
		local rank: number = nil
		local ok, err = pcall(function()
			-- GetRankInGroupAsync is deprecated, changed from GetRankInGroupAsync to GetRolesInGroupAsync
			-- ... but GetRolesInGroupAsync fails for some reason and hasn't been fixed (June 2, 2026)
			-- so we will fall back to a deprecated method anyway
			local result = GroupService:GetRolesInGroupAsync(player.UserId, groupId) :: GetRolesInGroupAsyncResult
			if result.IsMember then
				local highestRoleTable = _getHighestRoleTable(result.Roles)
				if highestRoleTable then
					rank = highestRoleTable.Rank
				end
			end
		end)
		if not rank then
			ok, err = pcall(function()
				local gotRank, _ = _getRankAndRoleFallback(player.UserId, groupId)
				rank = gotRank
			end)
		end

		if not ok then
			return reject(err)
		end

		if type(rank) ~= "number" then
			return reject("Rank is not a number")
		end

		return resolve(rank)
	end)
end

--[=[
	Retrieves the role of the player in the group.

	@param player Player
	@param groupId number
	@return Promise<string>
]=]
function GroupUtils.promiseRoleInGroup(player: Player, groupId: number): Promise.Promise<string>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(groupId) == "number", "Bad groupId")

	return Promise.spawn(function(resolve, reject)
		local role: string? = nil
		local ok, err = pcall(function()
			local result = GroupService:GetRolesInGroupAsync(player.UserId, groupId) :: GetRolesInGroupAsyncResult
			if result.IsMember then
				local highestRoleTable = _getHighestRoleTable(result.Roles)
				if highestRoleTable then
					role = highestRoleTable.Name
				end
			end
		end)

		if not role then
			ok, err = pcall(function()
				local _, gotRole = _getRankAndRoleFallback(player.UserId, groupId)
				role = gotRole
			end)
		end

		if not ok then
			return reject(err)
		end

		if type(role) ~= "string" then
			return reject("Role is not a string")
		end

		return resolve(role)
	end)
end

export type GroupRoleInfo = {
	Name: string,
	Rank: number,
}

export type GroupInfo = {
	Name: string,
	Id: number,
	Owner: {
		Name: string,
		Id: number,
	},
	EmblemUrl: string,
	Description: string,
	Roles: { GroupRoleInfo },
}

--[=[
	Retrieves groupInfo about a group.

	@param groupId number
	@return Promise<table>
]=]
function GroupUtils.promiseGroupInfo(groupId: number): Promise.Promise<GroupInfo>
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

--[=[
	Retrieves group role info for a given rankId

	@param groupId number
	@param rankId number
	@return Promise<table>
]=]
function GroupUtils.promiseGroupRoleInfo(groupId: number, rankId: number): Promise.Promise<GroupRoleInfo>
	assert(groupId, "Bad groupId")
	assert(rankId, "Bad rankId")

	return GroupUtils.promiseGroupInfo(groupId):Then(function(groupInfo)
		if type(groupInfo.Roles) ~= "table" then
			return Promise.rejected("No Roles table")
		end

		for _, rankInfo in groupInfo.Roles do
			if rankInfo.Rank == rankId then
				return rankInfo
			end
		end

		return Promise.rejected("No rank with given id")
	end)
end

return GroupUtils
