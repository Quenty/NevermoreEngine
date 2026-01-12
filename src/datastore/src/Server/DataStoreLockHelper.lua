--!strict
--[=[
    @class DataStoreLockHelper
]=]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DataStoreLockHelper = {}
DataStoreLockHelper.ClassName = "DataStoreLockHelper"
DataStoreLockHelper.__index = DataStoreLockHelper

local ALWAYS_STEAL_LOCKS_IN_STUDIO = false
local UNLOCK_BY_DEFAULT_TIME_MULTIPLIER = 2.1

export type DataStoreLockHelper = typeof(setmetatable(
	{} :: {
		_sessionId: string?,
		_dataStore: any,
	},
	{} :: typeof({ __index = DataStoreLockHelper })
))

export type LockData = number
export type ValidLockResult = {
	isValid: true,
	unlockedProfile: any,
	lockedProfile: any,
}

export type InvalidLockResult = {
	isValid: false,
}

export type AcquireLockResult = ValidLockResult | InvalidLockResult

function DataStoreLockHelper.new(dataStore: any): DataStoreLockHelper
	local self: DataStoreLockHelper = setmetatable({} :: any, DataStoreLockHelper)

	self._sessionId = HttpService:GenerateGUID(false)
	self._dataStore = dataStore

	return self
end

function DataStoreLockHelper.ToUnlockedProfile(_self: DataStoreLockHelper, original: any): any
	if original == nil then
		return {}
	elseif type(original) ~= "table" then
		warn("[DataStore] - Data session locking is not available for non-table entries")
		return original
	else
		local copy = table.clone(original)
		copy.lock = nil
		return copy
	end
end

function DataStoreLockHelper.ToLockedProfile(_self: DataStoreLockHelper, original: any, doCloseSession: boolean?): any
	if original == nil then
		return {
			lock = if doCloseSession then nil else os.time(),
		}
	elseif type(original) ~= "table" then
		warn("[DataStore] - Data session locking is not available for non-table entries")
		return original
	else
		local copy = table.clone(original)
		if doCloseSession then
			copy.lock = nil :: LockData?
		else
			copy.lock = os.time()
		end
		return copy
	end
end

function DataStoreLockHelper.AcquireLock(self: DataStoreLockHelper, data: any): AcquireLockResult
	if data == nil then
		return {
			isValid = true,
			unlockedProfile = {},
			lockedProfile = {
				lock = os.time(),
			},
		}
	elseif type(data) ~= "table" then
		warn("[DataStore] - Data session locking is not available for non-table entries")
		return {
			isValid = true,
			unlockedProfile = data,
			lockedProfile = data,
		}
	end

	local isValid = true
	if type(data.lock) == "number" then
		local timeElapsed = os.time() - data.lock
		local autoSaveSeconds = self._dataStore:GetAutoSaveTimeSeconds()
		if autoSaveSeconds and timeElapsed > (autoSaveSeconds * UNLOCK_BY_DEFAULT_TIME_MULTIPLIER) then
			isValid = false
		end
	end

	-- Allow data locked to load in studio because otherwise testing gets really messy
	if ALWAYS_STEAL_LOCKS_IN_STUDIO and RunService:IsStudio() then
		isValid = false
	end

	if isValid then
		return {
			isValid = true,
			unlockedProfile = self:ToUnlockedProfile(data),
			lockedProfile = self:ToLockedProfile(data),
		}
	else
		return {
			isValid = false,
		}
	end
end

return DataStoreLockHelper
