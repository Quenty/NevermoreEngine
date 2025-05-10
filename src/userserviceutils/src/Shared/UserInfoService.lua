--!strict
--[=[
	Centralized provider for user info so we can coordinate web requests.

	@class UserInfoService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local UserInfoAggregator = require("UserInfoAggregator")
local UserServiceUtils = require("UserServiceUtils")

local UserInfoService = {}
UserInfoService.ServiceName = "UserInfoService"

function UserInfoService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._aggregator = self._maid:Add(UserInfoAggregator.new())
end

--[=[
	Promises the user info for the given user, aggregating all requests to reduce
	calls into Roblox.

	@param userId number
	@return Promise<UserInfo>
]=]
function UserInfoService:PromiseUserInfo(userId: number): Promise.Promise<UserServiceUtils.UserInfo>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:PromiseUserInfo(userId)
end

--[=[
	Observes the user info for the user

	@param userId number
	@return Observable<UserInfo>
]=]
function UserInfoService:ObserveUserInfo(userId: number): Observable.Observable<UserServiceUtils.UserInfo>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:ObserveUserInfo(userId)
end

--[=[
	Promises the user display name for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoService:PromiseDisplayName(userId: number): Promise.Promise<string>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:PromiseDisplayName(userId)
end

--[=[
	Promises the Username for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoService:PromiseUsername(userId: number): Promise.Promise<string>
	assert(type(userId) == "number", "Bad userId")

	return self._aggregator:PromiseUsername(userId)
end

--[=[
	Observes the user display name for the userId

	@param userId number
	@return Observable<string>
]=]
function UserInfoService:ObserveDisplayName(userId: number): Observable.Observable<UserServiceUtils.UserInfo>
    assert(type(userId) == "number", "Bad userId")

	return self._aggregator:ObserveDisplayName(userId)
end


function UserInfoService:Destroy()
	self._maid:DoCleaning()
end

return UserInfoService