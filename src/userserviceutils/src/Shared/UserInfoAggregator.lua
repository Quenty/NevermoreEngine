--[=[
	Aggregates all requests into one big send request to deduplicate the request

	@class UserInfoAggregator
]=]

local require = require(script.Parent.loader).load(script)

local Aggregator = require("Aggregator")
local BaseObject = require("BaseObject")
local Rx = require("Rx")
local UserServiceUtils = require("UserServiceUtils")
local PromiseRetryUtils = require("PromiseRetryUtils")

local UserInfoAggregator = setmetatable({}, BaseObject)
UserInfoAggregator.ClassName = "UserInfoAggregator"
UserInfoAggregator.__index = UserInfoAggregator

function UserInfoAggregator.new()
	local self = setmetatable(BaseObject.new(), UserInfoAggregator)

	self._aggregator = self._maid:Add(Aggregator.new("UserServiceUtils.promiseUserInfosByUserIds", function(userIdList)
		return PromiseRetryUtils.retry(function()
			return UserServiceUtils.promiseUserInfosByUserIds(userIdList)
		end, {
			initialWaitTime = 10;
			maxAttempts = 10;
			printWarning = true;
		})
	end))

	return self
end

--[=[
	Promises the user info for the given user, aggregating all requests to reduce
	calls into Roblox.

	@param userId number
	@return Promise<UserInfo>
]=]
function UserInfoAggregator:PromiseUserInfo(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId)
end

--[=[
	Promises the user display name for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoAggregator:PromiseDisplayName(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId):Then(function(userInfo)
		return userInfo.DisplayName
	end)
end

--[=[
	Promises the Username for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoAggregator:PromiseUsername(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId):Then(function(userInfo)
		return userInfo.Username
	end)
end

--[=[
	Promises the user display name for the userId

	@param userId number
	@return Promise<boolean>
]=]
function UserInfoAggregator:PromiseHasVerifiedBadge(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId):Then(function(userInfo)
		return userInfo.HasVerifiedBadge
	end)
end

--[=[
	Observes the user display name for the userId

	@param userId number
	@return Observable<UserInfo>
]=]
function UserInfoAggregator:ObserveUserInfo(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId)
end

--[=[
	Observes the user display name for the userId

	@param userId number
	@return Observable<string>
]=]
function UserInfoAggregator:ObserveDisplayName(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId):Pipe({
		Rx.map(function(userInfo)
			return userInfo.DisplayName
		end),
	})
end

--[=[
	Observes the Username for the userId

	@param userId number
	@return Observable<string>
]=]
function UserInfoAggregator:ObserveUsername(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId):Pipe({
		Rx.map(function(userInfo)
			return userInfo.Username
		end),
	})
end

--[=[
	Observes the user display name for the userId

	@param userId number
	@return Observable<boolean>
]=]
function UserInfoAggregator:ObserveHasVerifiedBadge(userId: number)
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId):Pipe({
		Rx.map(function(userInfo)
			return userInfo.HasVerifiedBadge
		end)
	})
end

return UserInfoAggregator