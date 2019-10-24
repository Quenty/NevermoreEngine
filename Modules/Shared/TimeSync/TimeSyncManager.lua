--- Fallback for TimeSyncService not being used
-- @module TimeSyncManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

warn("[TimeSyncManager] - Should use TimeSyncService instead!")

local TimeSyncService = require("TimeSyncService")

TimeSyncService:Init()

return TimeSyncService:WaitForSyncedClock()