--!strict
--[=[
    @class DataStoreLockHelper
]=]

local RunService = game:GetService("RunService")

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Promise = require("Promise")

local DataStoreLockHelper = setmetatable({}, BaseObject)
DataStoreLockHelper.ClassName = "DataStoreLockHelper"
DataStoreLockHelper.__index = DataStoreLockHelper

local ALWAYS_STEAL_LOCKS_IN_STUDIO = true
local UNLOCK_BY_DEFAULT_TIME_MULTIPLIER = 2.1

export type DataStoreLockHelper =
	typeof(setmetatable(
		{} :: {
			_dataStore: any,
			_sessionClosedPromise: Promise.Promise<()>,
		},
		{} :: typeof({ __index = DataStoreLockHelper })
	))
	& BaseObject.BaseObject

export type LockedSessionData = {
	SessionId: string,
	PlaceId: number,
	JobId: string,
}

export type LockData = {
	LastUpdateTime: number?,
	ActiveSession: LockedSessionData?,
}

export type AcquiredValidLockResult = {
	isValid: true,
	stolenLockFromSession: LockedSessionData?,
	unlockedProfile: any,
	lockedProfile: any,
}

export type AcquiredInvalidLockResult = {
	isValid: false,
	blockingSession: LockedSessionData,
}

export type AcquireLockResult = AcquiredValidLockResult | AcquiredInvalidLockResult

export type ValidUnlockedProfileResult = {
	isValid: true,
	unlockedProfile: any,
}

export type InvalidUnlockedProfileResult = {
	isValid: false,
	thiefSession: LockedSessionData,
}
export type UnlockedProfileResult = ValidUnlockedProfileResult | InvalidUnlockedProfileResult

function DataStoreLockHelper.new(dataStore: any): DataStoreLockHelper
	local self: DataStoreLockHelper = setmetatable(BaseObject.new() :: any, DataStoreLockHelper)

	self._dataStore = assert(dataStore, "No dataStore")
	self._sessionClosedPromise = Promise.new()
	self._maid:GiveTask(function()
		self._sessionClosedPromise:Reject()
	end)

	return self
end

function DataStoreLockHelper.ToUnlockedProfile(self: DataStoreLockHelper, original: any): UnlockedProfileResult
	if original == nil then
		return {
			isValid = true,
			unlockedProfile = {},
		}
	elseif type(original) ~= "table" then
		warn("[DataStoreLockHelper] - Data session locking is not available for non-table entries")
		return {
			isValid = true,
			unlockedProfile = original,
		}
	else
		local parsedLockData = self:_deserializeLockData(original.lock)
		if parsedLockData == nil or parsedLockData.ActiveSession == nil then
			return {
				isValid = true,
				unlockedProfile = self:ToRawUnlockedProfile(original),
			}
		end

		if self:_isInSession(parsedLockData.ActiveSession) then
			-- We own the lock
			return {
				isValid = true,
				unlockedProfile = self:ToRawUnlockedProfile(original),
			}
		elseif self:_isLockStale(parsedLockData) then
			-- Held by a session this protocol already considers dead. AcquireLock would take this
			-- lock rather than wait for it, so reporting theft here would have the two halves
			-- disagreeing about the same predicate -- and the cost of that disagreement is a
			-- kicked player and the save that was about to land, over a session that died hours
			-- ago and is never coming back to claim it.
			return {
				isValid = true,
				unlockedProfile = self:ToRawUnlockedProfile(original),
			}
		else
			-- Someone else owns the lock
			return {
				isValid = false,
				thiefSession = parsedLockData.ActiveSession,
			}
		end
	end
end

function DataStoreLockHelper.ToRawUnlockedProfile(_self: DataStoreLockHelper, original: any): any
	if original == nil then
		return {}
	elseif type(original) ~= "table" then
		warn("[DataStoreLockHelper] - Data session locking is not available for non-table entries")
		return original
	else
		local copy = table.clone(original)
		copy.lock = nil
		return copy
	end
end

function DataStoreLockHelper.ToLockedProfile(self: DataStoreLockHelper, original: any, doCloseSession: boolean?): any
	if doCloseSession then
		self._sessionClosedPromise:Resolve()
	end

	if original == nil then
		if doCloseSession then
			return {}
		else
			return {
				lock = {
					LastUpdateTime = os.time(),
					ActiveSession = self:_ourCurrentSessionData(),
				} :: LockData,
			}
		end
	elseif type(original) ~= "table" then
		warn("[DataStoreLockHelper] - Data session locking is not available for non-table entries")
		return original
	else
		local copy = table.clone(original)
		if doCloseSession then
			copy.lock = nil :: LockData?
		else
			copy.lock = {
				LastUpdateTime = os.time(),
				ActiveSession = self:_ourCurrentSessionData(),
			} :: LockData
		end

		return copy
	end
end

--[=[
	Whether a lock is old enough that the session holding it is assumed dead.

	A session refreshes its lock whenever it actually writes, so a lock that has gone several
	auto-save intervals without moving most likely belongs to a server that crashed. (A live but
	fully idle session can go quiet that long too, since a save with nothing staged skips the
	write -- the load side has always accepted stealing such a lock, and that session's own next
	real save then reads as theft and closes it out.) Both halves of the protocol ask this
	predicate, and they have to agree: a lock the load will take is one the save must not report
	as theft.

	@private
	@param parsedLockData LockData?
	@return boolean
]=]
function DataStoreLockHelper._isLockStale(self: DataStoreLockHelper, parsedLockData: LockData?): boolean
	if parsedLockData == nil or parsedLockData.LastUpdateTime == nil then
		return false
	end

	local autoSaveSeconds = self._dataStore:GetAutoSaveTimeSeconds()
	if not autoSaveSeconds then
		return false
	end

	local timeElapsed = os.time() - parsedLockData.LastUpdateTime
	return timeElapsed > (autoSaveSeconds * UNLOCK_BY_DEFAULT_TIME_MULTIPLIER)
end

function DataStoreLockHelper._isInSession(self: DataStoreLockHelper, sessionData: LockedSessionData): boolean
	local ourData = self:_ourCurrentSessionData()

	if sessionData.SessionId ~= ourData.SessionId then
		return false
	end
	if sessionData.PlaceId ~= ourData.PlaceId then
		return false
	end
	if sessionData.JobId ~= ourData.JobId then
		return false
	end
	return true
end

function DataStoreLockHelper._ourCurrentSessionData(self: DataStoreLockHelper): LockedSessionData
	return {
		SessionId = self._dataStore:GetSessionId(),
		PlaceId = game.PlaceId,
		JobId = game.JobId,
	}
end

function DataStoreLockHelper._deserializeSessionData(_self: DataStoreLockHelper, sessionData: any): LockedSessionData?
	if type(sessionData) ~= "table" then
		return nil
	end

	if type(sessionData.SessionId) ~= "string" then
		return nil
	end

	if type(sessionData.PlaceId) ~= "number" then
		return nil
	end

	if type(sessionData.JobId) ~= "string" then
		return nil
	end

	return {
		SessionId = sessionData.SessionId,
		PlaceId = sessionData.PlaceId,
		JobId = sessionData.JobId,
	}
end

function DataStoreLockHelper._deserializeLockData(self: DataStoreLockHelper, lockData: any): LockData?
	if type(lockData) ~= "table" then
		return nil
	end

	local activeSession: LockedSessionData? = self:_deserializeSessionData(lockData.ActiveSession)

	return {
		LastUpdateTime = if type(lockData.LastUpdateTime) == "number" then lockData.LastUpdateTime else nil,
		ActiveSession = activeSession,
	}
end

function DataStoreLockHelper.PromiseCloseSession(self: DataStoreLockHelper): Promise.Promise<()>
	return self._sessionClosedPromise
end

function DataStoreLockHelper.AcquireLock(self: DataStoreLockHelper, data: any, canStealLock: boolean): AcquireLockResult
	if self._sessionClosedPromise:IsFulfilled() then
		self._sessionClosedPromise = Promise.new()
	end

	if data == nil then
		return {
			isValid = true,
			stolenLockFromSession = nil,
			unlockedProfile = self:ToRawUnlockedProfile(data),
			lockedProfile = self:ToLockedProfile(data),
		}
	elseif type(data) ~= "table" then
		warn("[DataStore] - Data session locking is not available for non-table entries")
		return {
			isValid = true,
			stolenLockFromSession = nil,
			unlockedProfile = data,
			lockedProfile = data,
		}
	end

	local parsedLockData = self:_deserializeLockData(data.lock)
	if parsedLockData == nil or parsedLockData.ActiveSession == nil then
		return {
			isValid = true,
			stolenLockFromSession = nil,
			unlockedProfile = self:ToRawUnlockedProfile(data),
			lockedProfile = self:ToLockedProfile(data),
		}
	end

	if self:_isInSession(parsedLockData.ActiveSession) then
		return {
			isValid = true,
			stolenLockFromSession = nil,
			unlockedProfile = self:ToRawUnlockedProfile(data),
			lockedProfile = self:ToLockedProfile(data),
		}
	end

	-- We're locked out, but there's conditions where it's ok to steal the lock

	local lockStealingOk = canStealLock or self:_isLockStale(parsedLockData)

	if ALWAYS_STEAL_LOCKS_IN_STUDIO and RunService:IsStudio() then
		lockStealingOk = true
	end

	if lockStealingOk then
		return {
			isValid = true,
			stolenLockFromSession = parsedLockData.ActiveSession,
			unlockedProfile = self:ToRawUnlockedProfile(data),
			lockedProfile = self:ToLockedProfile(data),
		}
	else
		return {
			isValid = false,
			blockingSession = parsedLockData.ActiveSession,
		}
	end
end

return DataStoreLockHelper
