--[=[
	Aggregates all requests into one big send request

	@class UserInfoAggregator
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local UserServiceUtils = require("UserServiceUtils")

local UserInfoAggregator = setmetatable({}, BaseObject)
UserInfoAggregator.ClassName = "UserInfoAggregator"
UserInfoAggregator.__index = UserInfoAggregator

function UserInfoAggregator.new()
	local self = setmetatable(BaseObject.new(), UserInfoAggregator)

	-- TODO: LRU cache this? Limit to 1k or something?
	self._promises = {}
	self._unsentPromises = {}

	return self
end

--[=[
	Promises the user info for the given user, aggregating all requests to reduce
	calls into Roblox.

	@param userId number
	@return Promise<UserInfo>
]=]
function UserInfoAggregator:PromiseUserInfo(userId)
	assert(type(userId) == "number", "Bad userId")

	if self._promises[userId] then
		return self._promises[userId]
	end

	local promise = Promise.new()

	self._unsentPromises[userId] = promise
	self._promises[userId] = promise

	self:_queueAggregatedPromises()

	return promise
end

--[=[
	Promises the user display name for the userId

	@param userId number
	@return Promise<string>
]=]
function UserInfoAggregator:PromiseDisplayName(userId)
	assert(type(userId) == "number", "Bad userId")

	return self:PromiseUserInfo(userId)
		:Then(function(userInfo)
			return userInfo.DisplayName
		end)
end

function UserInfoAggregator:_sendAggregatedPromises()
	local promiseMap = self._unsentPromises
	self._unsentPromises = {}

	local userIds = {}
	local unresolvedMap = {}
	for userId, promise in pairs(promiseMap) do
		table.insert(userIds, userId)
		unresolvedMap[userId] = promise
	end

	if #userIds == 0 then
		return
	end

	self._maid:GivePromise(UserServiceUtils.promiseUserInfosByUserIds(userIds))
		:Then(function(result)
			assert(type(result) == "table", "Bad result")

			for _, data in pairs(result) do
				assert(type(data.Id) == "number", "Bad result[?].Id")

				if unresolvedMap[data.Id] then
					unresolvedMap[data.Id]:Resolve(data)
					unresolvedMap[data.Id] = nil
				end
			end

			-- Reject other ones
			for userId, promise in pairs(unresolvedMap) do
				promise:Reject(string.format("Failed to get result for userId %d", userId))
			end
		end, function(...)
			for _, item in pairs(promiseMap) do
				item:Reject(...)
			end
		end)
end

function UserInfoAggregator:_queueAggregatedPromises()
	if self._queued then
		return
	end

	self._queued = true
	self._maid._queue = task.delay(0.05, function()
		self._queued = false
		self:_sendAggregatedPromises()
	end)
end



return UserInfoAggregator