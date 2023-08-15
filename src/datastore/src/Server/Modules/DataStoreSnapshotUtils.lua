--[=[
	@class DataStoreSnapshotUtils
]=]

local require = require(script.Parent.loader).load(script)

local DataStoreSnapshotUtils = {}

function DataStoreSnapshotUtils.isEmptySnapshot(snapshot)
	return type(snapshot) == "table" and next(snapshot) == nil
end

return DataStoreSnapshotUtils