---
-- @module VoteService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local HttpPromise = require("HttpPromise")
local Promise = require("Promise")
local Maid = require("Maid")
local deferred = require("deferred")

local UPDATE_RATE = 15

local VoteService = {}

function VoteService:Init()
	self._maid = Maid.new()
end

function VoteService:GetUpVotesValue()
	assert(self._maid, "Not initialized")

	self:_startUpdateAsNeeded()

	return assert(self._upVotes)
end

function VoteService:GetDownVotesValue()
	assert(self._maid, "Not initialized")

	self:_startUpdateAsNeeded()

	return assert(self._downVotes)
end

function VoteService:_startUpdateAsNeeded()
	if self._upVotes then
		return
	end

	self._upVotes = Instance.new("IntValue")
	self._upVotes.Value = 0

	self._downVotes = Instance.new("IntValue")
	self._downVotes.Value = 0

	deferred(function()
		while true do
			self:_update()
			wait(UPDATE_RATE)
		end
	end)
end

function VoteService:_update()
	assert(self._maid, "Not initialized")
	assert(self._upVotes, "No updated started")
	assert(self._downVotes, "No updated started")

	-- We're already pending an update...
	if self._maid._promise and self._maid._promise:IsPending() then
		return
	end

	local promise = self:_promiseGameVotes()
	self._maid._promise = promise

	return promise:Then(function(data)
		self:_processVoteData(data)
	end)
end

function VoteService:_processVoteData(data)
	assert(self._upVotes, "Not initialized")

	local upVotes = tonumber(data.upVotes)
	if type(upVotes) == "number" then
		self._upVotes.Value = upVotes
	else
		warn("[VoteService] - Unable to get upVotes")
	end

	local downVotes = tonumber(data.downVotes)
	if type(downVotes) == "number" then
		self._downVotes.Value = downVotes
	else
		warn("[VoteService] - Unable to get downVotes")
	end
end

function VoteService:_promiseGameVotes()
	return HttpPromise.json(string.format("https://quenty.org/rbxapi/games/votes/%s", game.GameId))
		:Then(function(data)
			assert(type(data) == "table")

			if data.error then
				return Promise.rejected(data.error)
			else
				return data
			end
		end)
end


return VoteService