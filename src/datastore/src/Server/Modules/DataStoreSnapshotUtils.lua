--[=[
	@class DataStoreSnapshotUtils
]=]

local require = require(script.Parent.loader).load(script)

local Symbol = require("Symbol")

local DataStoreSnapshotUtils = {}

function DataStoreSnapshotUtils.isEmptySnapshot(snapshot: any): boolean
	return not Symbol.isSymbol(snapshot) and type(snapshot) == "table" and next(snapshot) == nil
end

return DataStoreSnapshotUtils