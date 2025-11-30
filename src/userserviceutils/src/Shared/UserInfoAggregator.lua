--!strict
--[=[
	Aggregates all requests into one big send request to deduplicate the request

	@class UserInfoAggregator
]=]

local require = require(script.Parent.loader).load(script)

local Aggregator = require("Aggregator")
local BaseObject = require("BaseObject")
local Observable = require("Observable")
local Promise = require("Promise")
local PromiseRetryUtils = require("PromiseRetryUtils")
local Rx = require("Rx")
local UserServiceUtils = require("UserServiceUtils")

local UserInfoAggregator = setmetatable({}, BaseObject)
UserInfoAggregator.ClassName = "UserInfoAggregator"
UserInfoAggregator.__index = UserInfoAggregator

export type UserInfoAggregator = typeof(setmetatable(
	{} :: {
		_aggregator: Aggregator.Aggregator<UserServiceUtils.UserInfo>,
	},
	{} :: typeof({ __index = UserInfoAggregator })
)) & BaseObject.BaseObject

function UserInfoAggregator.new(): UserInfoAggregator
	local self: UserInfoAggregator = setmetatable(BaseObject.new() :: any, UserInfoAggregator)

	self._aggregator = self._maid:Add(Aggregator.new("UserServiceUtils.promiseUserInfosByUserIds", function(userIdList)
		return PromiseRetryUtils.retry(function()
			return UserServiceUtils.promiseUserInfosByUserIds(userIdList)
		end, {
			initialWaitTime = 10,
			maxAttempts = 10,
			printWarning = true,
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
function UserInfoAggregator:PromiseUserInfo(userId: number): Promise.Promise<UserServiceUtils.UserInfo>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId)
end

--[=[
	Promises the user display name for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoAggregator:PromiseDisplayName(userId: number): Promise.Promise<string>
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
function UserInfoAggregator:PromiseUsername(userId: number): Promise.Promise<string>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId):Then(function(userInfo)
		return userInfo.Username
	end)
end

--[=[
	Promises the user verified badge state for the userId

	@param userId number
	@return Promise<boolean>
]=]
function UserInfoAggregator:PromiseHasVerifiedBadge(userId: number): Promise.Promise<boolean>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Promise(userId):Then(function(userInfo)
		return userInfo.HasVerifiedBadge
	end)
end

--[=[
	Observes the user info for the userId

	@param userId number
	@return Observable<UserInfo>
]=]
function UserInfoAggregator:ObserveUserInfo(userId: number): Observable.Observable<UserServiceUtils.UserInfo>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId)
end

--[=[
	Observes the user display name for the userId

	@param userId number
	@return Observable<string>
]=]
function UserInfoAggregator:ObserveDisplayName(userId: number): Observable.Observable<string>
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
function UserInfoAggregator:ObserveUsername(userId: number): Observable.Observable<string>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId):Pipe({
		Rx.map(function(userInfo)
			return userInfo.Username
		end),
	})
end

--[=[
	Observes the user verified badge state for the userId

	@param userId number
	@return Observable<boolean>
]=]
function UserInfoAggregator:ObserveHasVerifiedBadge(userId: number): Observable.Observable<boolean>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:Observe(userId):Pipe({
		Rx.map(function(userInfo)
			return userInfo.HasVerifiedBadge
		end),
	})
end

return UserInfoAggregator
