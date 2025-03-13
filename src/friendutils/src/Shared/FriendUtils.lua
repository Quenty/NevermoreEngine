--!strict
--[=[
	Utlity functions to help find friends of a user. Also contains utility to make testing in studio easier.
	@class FriendUtils
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Promise = require("Promise")

local FriendUtils = {}

--[=[
	@interface FriendData
	.Id number -- The friend's UserId
	.Username string -- The friend's username
	.DisplayName string -- The display name of the friend.
	.IsOnline bool -- If the friend is currently online
	@within FriendUtils
]=]
export type FriendData = {
	Id: number,
	Username: string,
	DisplayName: string,
	IsOnline: boolean,
}

--[=[
	Returns the current studio users friends

	```lua
	FriendUtils.promiseAllStudioFriends()
		:Then(function(studioFriends)
			print(studioFriends)
		end)
	```
	@return Promise<{ FriendData }>
]=]
function FriendUtils.promiseAllStudioFriends(): Promise.Promise<{ FriendData }>
	return FriendUtils.promiseCurrentStudioUserId():Then(FriendUtils.promiseAllFriends)
end

--[=[
	Outputs a list of only online friends
	@param friends { FriendData }
	@return { FriendData }
]=]
function FriendUtils.onlineFriends(friends: { FriendData }): { FriendData }
	local onlineFriends = {}
	for _, friend in friends do
		if friend.IsOnline then
			table.insert(onlineFriends, friend)
		end
	end
	return onlineFriends
end

--[=[
	Outputs a list of only friends not in game
	@param friends { FriendData }
	@return { FriendData }
]=]
function FriendUtils.friendsNotInGame(friends: { FriendData }): { FriendData }
	local userIdsInGame = {}
	for _, player in Players:GetPlayers() do
		userIdsInGame[player.UserId] = true
	end

	local onlineFriends = {}
	for _, friend in friends do
		if not userIdsInGame[friend.Id] then
			table.insert(onlineFriends, friend)
		end
	end
	return onlineFriends
end

--[=[
	Retrieves all friends.
	@param userId number
	@param limitMaxFriends number? -- Optional max friends
	@return Promise<{ FriendData }>
]=]
function FriendUtils.promiseAllFriends(userId: number, limitMaxFriends: number?): Promise.Promise<{ FriendData }>
	assert(userId, "Bad userId")

	return FriendUtils.promiseFriendPages(userId):Then(function(pages)
		return Promise.spawn(function(resolve, _)
			local users = {}

			for userData in FriendUtils.iterateFriendsYielding(pages) do
				table.insert(users, userData)

				-- Exit quickly!
				if limitMaxFriends and #users >= limitMaxFriends then
					return resolve(users)
				end
			end

			return resolve(users)
		end)
	end)
end

--[=[
	Wraps [Players.GetFriendsAsync]
	@param userId number
	@return Promise<FriendPages>
]=]
function FriendUtils.promiseFriendPages(userId: number): Promise.Promise<FriendPages>
	assert(type(userId) == "number", "Bad userId")

	return Promise.spawn(function(resolve, reject)
		local pages
		local ok, err = pcall(function()
			pages = Players:GetFriendsAsync(userId)
		end)
		if not ok then
			return reject(err)
		end
		if not pages then
			return reject("failed to get a friends page")
		end
		return resolve(pages)
	end)
end

--[=[
	Iterates over the current FriendPage and returns the next page
	@param pages FriendPages
	@return () => FrienData? -- Iterator
]=]
function FriendUtils.iterateFriendsYielding(pages: FriendPages): () -> FriendData?
	assert(pages, "Bad pages")

	return coroutine.wrap(function()
		while true do
			for _, userData in pages:GetCurrentPage() do
				assert(type(userData.Id) == "number", "Bad userData.Id")
				assert(type(userData.Username) == "string", "Bad userData.Username")
				assert(type(userData.IsOnline) == "boolean", "Bad userData.IsOnline")

				coroutine.yield(userData)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
end

--[=[
	Gets the current studio user's user id.

	:::tip
	Consider using [FriendUtils.promiseCurrentStudioUserId] if you want this code
	to work while the game is running or in team create. This is specific to [StudioService].
	:::

	@return Promise<number>
]=]
function FriendUtils.promiseStudioServiceUserId(): Promise.Promise<number>
	return Promise.new(function(resolve, reject)
		local userId
		local ok, err = pcall(function()
			-- only works from a plugin. Good news is, a story is a plugin.
			local StudioService = game:GetService("StudioService")
			userId = StudioService:GetUserId()
		end)

		if not ok then
			return reject(err)
		elseif type(userId) ~= "number" then
			return reject("no userId returned")
		else
			return resolve(userId)
		end
	end)
end

--[=[
	Gets the current studio user's user id.
	@return Promise<number>
]=]
function FriendUtils.promiseCurrentStudioUserId(): Promise.Promise<number>
	return FriendUtils.promiseStudioServiceUserId()
		:Catch(function(...)
			warn(...)

			-- this is in team create!
			local player = Players:FindFirstChildWhichIsA("Player")
			if player then
				return player.UserId
			end

			-- default to Quenty
			return 4397833
		end)
end

return FriendUtils