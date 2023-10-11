--[=[
	Wraps [UserService] API calls with [Promise].

	@class UserServiceUtils
]=]

local require = require(script.Parent.loader).load(script)

local UserService = game:GetService("UserService")

local Promise = require("Promise")

local UserServiceUtils = {}

--[=[
	@interface UserInfo
	.Id number -- The Id associated with the UserInfoResponse object
	.Username string -- The username associated with the UserInfoResponse object
	.DisplayName string	 -- The display name associated with the UserInfoResponse object
	.HasVerifiedBadge boolean -- The HasVerifiedBadge value associated with the user.
	@within UserServiceUtils
]=]

--[=[
	Wraps UserService:GetUserInfosByUserIdsAsync(userIds)

	::: tip
	User [UserInfoAggregator] via [UserInfoService] to get this deduplicated.
	:::

	@param userIds { number }
	@return Promise<{ UserInfo }>
]=]
function UserServiceUtils.promiseUserInfosByUserIds(userIds)
	assert(type(userIds) == "table", "Bad userIds")

	return Promise.spawn(function(resolve, reject)
		local userInfos
		local ok, err = pcall(function()
			userInfos = UserService:GetUserInfosByUserIdsAsync(userIds)
		end)
		if not ok then
			return reject(err)
		end

		if type(userInfos) ~= "table" then
			return reject("Failed to get an array of user infos back")
		end

		return resolve(userInfos)
	end)
end

--[=[
	Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1]

	::: tip
	User [UserInfoAggregator] via [UserInfoService] to get this deduplicated.
	:::

	@param userId number
	@return Promise<UserInfo>
]=]
function UserServiceUtils.promiseUserInfo(userId)
	assert(type(userId) == "number", "Bad userId")

	return UserServiceUtils.promiseUserInfosByUserIds({ userId })
		:Then(function(infos)
			local userInfo = infos[1]

			if not userInfo then
				return Promise.rejected("Failed to retrieve data for userId")
			end

			return userInfo
		end)
end

--[=[
	Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1].DisplayName

	::: tip
	User [UserInfoAggregator] via [UserInfoService] to get this deduplicated.
	:::

	@param userId number
	@return Promise<string>
]=]
function UserServiceUtils.promiseDisplayName(userId)
	assert(type(userId) == "number", "Bad userId")

	return UserServiceUtils.promiseUserInfo(userId)
		:Then(function(userInfo)
			return userInfo.DisplayName
		end)
end

--[=[
	Wraps UserService:GetUserInfosByUserIdsAsync({ userId })[1].Username

	::: tip
	User [UserInfoAggregator] via [UserInfoService] to get this deduplicated.
	:::

	@param userId number
	@return Promise<string>
]=]
function UserServiceUtils.promiseUserName(userId)
	assert(type(userId) == "number", "Bad userId")

	return UserServiceUtils.promiseUserInfo(userId)
		:Then(function(userInfo)
			return userInfo.Username
		end)
end

return UserServiceUtils