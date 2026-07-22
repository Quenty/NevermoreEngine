--!strict
--[=[
	Helpers for injecting group membership onto a [PlayerMock] in tests.

	[GroupUtils] answers rank and role from two engine calls -- `GetRolesInGroupAsync`
	(primary) and `GetGroupsAsync` (fallback) -- and only those calls are intercepted for
	mocks, so its parsing and fallback logic runs for real in tests. [GroupTestUtils.assignGroupInfo]
	writes both injected results from one rank/role pair so the answer is coherent whichever
	path production code takes.

	@class GroupTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMock = require("PlayerMock")

local GroupTestUtils = {}

export type AssignedGroupInfo = {
	rank: number,
	role: string,
}

--[=[
	Injects membership in a group for a mock at both engine calls [GroupUtils] reads, replacing
	any earlier assignment for the same group. Assign multiple groups by calling once per group.

	```lua
	GroupTestUtils.assignGroupInfo(playerMock, 372, { rank = 230, role = "Admin" })
	-- GroupUtils.promiseRankInGroup(playerMock, 372) resolves 230,
	-- promiseRoleInGroup(playerMock, 372) resolves "Admin"
	```

	@param player Player -- must be a PlayerMock
	@param groupId number
	@param groupInfo { rank: number, role: string }
]=]
function GroupTestUtils.assignGroupInfo(player: Player, groupId: number, groupInfo: AssignedGroupInfo)
	assert(PlayerMock.isMock(player), "Not a PlayerMock")
	assert(type(groupId) == "number", "Bad groupId")
	assert(type(groupInfo) == "table", "Bad groupInfo")
	assert(type(groupInfo.rank) == "number", "Bad groupInfo.rank")
	assert(type(groupInfo.role) == "string", "Bad groupInfo.role")

	PlayerMock.writeLookup(player, "GroupService.GetRolesInGroupAsync", groupId, {
		IsMember = true,
		Roles = { { Name = groupInfo.role, Rank = groupInfo.rank } },
	})

	local groups = PlayerMock.readLookup(player, "GroupService.GetGroupsAsync", 0)
	local updated = {}
	for _, existing in groups do
		if existing.Id ~= groupId then
			table.insert(updated, existing)
		end
	end
	table.insert(updated, {
		Id = groupId,
		Rank = groupInfo.rank,
		Role = groupInfo.role,
	})
	PlayerMock.writeLookup(player, "GroupService.GetGroupsAsync", 0, updated)
end

return GroupTestUtils
