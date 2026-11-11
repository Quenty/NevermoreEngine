--!strict
--[=[
	Pure reading and writing of the session-lock envelope a [DataStore] keeps under the `lock` field.

	[DataStoreLockHelper] owns the live path, where the lock is only ever touched by the session that
	holds it. Tooling needs the other path: inspect or clear the lock on a key belonging to a player
	who is not in this server, through a raw datastore write with no session at all. Both go through
	here so there is one definition of the envelope.

	@server
	@class DataStoreLockUtils
]=]

local DataStoreLockUtils = {}

export type LockedSessionData = {
	SessionId: string,
	PlaceId: number,
	JobId: string,
}

export type LockData = {
	LastUpdateTime: number?,
	ActiveSession: LockedSessionData?,
}

--[=[
	Reads session data back out of whatever the datastore returned, rejecting anything malformed.

	@param sessionData any
	@return LockedSessionData?
]=]
function DataStoreLockUtils.deserializeSessionData(sessionData: any): LockedSessionData?
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

--[=[
	Reads a lock envelope back out of whatever the datastore returned.

	@param lockData any
	@return LockData?
]=]
function DataStoreLockUtils.deserializeLockData(lockData: any): LockData?
	if type(lockData) ~= "table" then
		return nil
	end

	return {
		LastUpdateTime = if type(lockData.LastUpdateTime) == "number" then lockData.LastUpdateTime else nil,
		ActiveSession = DataStoreLockUtils.deserializeSessionData(lockData.ActiveSession),
	}
end

--[=[
	Reads the lock off a whole stored profile.

	@param data any -- the raw value stored at the key
	@return LockData?
]=]
function DataStoreLockUtils.readLock(data: any): LockData?
	if type(data) ~= "table" then
		return nil
	end

	return DataStoreLockUtils.deserializeLockData(data.lock)
end

--[=[
	Builds the envelope a session writes to claim the key.

	@param sessionData LockedSessionData
	@param lastUpdateTime number? -- defaults to now
	@return LockData
]=]
function DataStoreLockUtils.createLockData(sessionData: LockedSessionData, lastUpdateTime: number?): LockData
	return {
		LastUpdateTime = lastUpdateTime or os.time(),
		ActiveSession = sessionData,
	}
end

--[=[
	Returns a copy of the profile with the lock set to `lockData`, or cleared when it is nil.

	@param data any -- the raw value stored at the key
	@param lockData LockData?
	@return any
]=]
function DataStoreLockUtils.withLock(data: any, lockData: LockData?): any
	if data == nil then
		return if lockData == nil then {} else { lock = lockData }
	elseif type(data) ~= "table" then
		warn("[DataStoreLockUtils] - Data session locking is not available for non-table entries")
		return data
	end

	local copy = table.clone(data)
	copy.lock = lockData
	return copy
end

--[=[
	Renders a lock for a human reading command output.

	@param lockData LockData?
	@return string
]=]
function DataStoreLockUtils.toHumanReadable(lockData: LockData?): string
	if lockData == nil or lockData.ActiveSession == nil then
		return "unlocked"
	end

	local session = lockData.ActiveSession
	local age = if lockData.LastUpdateTime then `{os.time() - lockData.LastUpdateTime}s ago` else "unknown age"

	return `locked by PlaceId {session.PlaceId}, JobId {session.JobId}, SessionId {session.SessionId} (updated {age})`
end

return DataStoreLockUtils
