--- Utlity functions to help find friends of a user. Also contains utility to make testing in studio easier.
-- @module FriendUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local Promise = require("Promise")

local FriendUtils = {}

function FriendUtils.promiseAllStudioFriends()
	return FriendUtils.promiseCurrentStudioUserId()
		:Then(FriendUtils.promiseAllFriends)
end

function FriendUtils.onlineFriends(friends)
	local onlineFriends = {}
	for _, friend in pairs(friends) do
		if friend.IsOnline then
			table.insert(onlineFriends, friend)
		end
	end
	return onlineFriends
end

function FriendUtils.friendsNotInGame(friends)
	local userIdsInGame = {}
	for _, player in pairs(Players:GetPlayers()) do
		userIdsInGame[player.UserId] = true
	end

	local onlineFriends = {}
	for _, friend in pairs(friends) do
		if not userIdsInGame[friend.Id] then
			table.insert(onlineFriends, friend)
		end
	end
	return onlineFriends
end

-- @param[opt=nil] limitMaxFriends
function FriendUtils.promiseAllFriends(userId, limitMaxFriends)
	assert(userId)

	return FriendUtils.promiseFriendPages(userId)
		:Then(function(pages)
			return Promise.spawn(function(resolve, reject)
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

function FriendUtils.promiseFriendPages(userId)
	assert(type(userId) == "number")

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

function FriendUtils.iterateFriendsYielding(pages)
	assert(pages)

	return coroutine.wrap(function()
		while true do
			for _, userData in pairs(pages:GetCurrentPage()) do
				assert(type(userData.Id) == "number")
				assert(type(userData.Username) == "string")
				assert(type(userData.IsOnline) == "boolean")

				coroutine.yield(userData)
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
end

function FriendUtils.promiseStudioServiceUserId()
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

function FriendUtils.promiseCurrentStudioUserId()
	return FriendUtils.promiseStudioServiceUserId()
		:Catch(function(...)
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