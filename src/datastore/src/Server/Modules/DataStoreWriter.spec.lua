--!nonstrict
--[[
	Characterization coverage for DataStoreWriter's merge/diff/write API -- what actually gets
	persisted when new data, delete tokens, and nested sub-writers are layered onto an original.
	@class DataStoreWriter.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local DataStoreDeleteToken = require("DataStoreDeleteToken")
local DataStoreWriter = require("DataStoreWriter")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Recursively freeze so snapshots satisfy the "must be frozen" asserts on Set*Snapshot.
local function deepFreeze<T>(tab: T): T
	if type(tab) == "table" and not table.isfrozen(tab :: any) then
		for _, value in tab :: any do
			deepFreeze(value)
		end
		table.freeze(tab :: any)
	end
	return tab
end

describe("DataStoreWriter.new", function()
	it("should construct with a debugName and expose the ClassName", function()
		local writer = DataStoreWriter.new("test")

		expect(writer).never.toBeNil()
		expect(writer.ClassName).toEqual("DataStoreWriter")
	end)

	it("should error when constructed without a debugName", function()
		expect(function()
			DataStoreWriter.new()
		end).toThrow("No debugName")
	end)

	it("should start with empty/unset state", function()
		local writer = DataStoreWriter.new("test")

		expect(writer:GetDataToSave()).toBeNil()
		expect(writer:GetUserIdList()).toBeNil()
		expect(writer:GetSubWritersMap()).toEqual({})
		expect(writer:IsCompleteWipe()).toEqual(false)
	end)
end)

describe("DataStoreWriter:SetSaveDataSnapshot / GetDataToSave", function()
	it("should store and return a scalar save value", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(5)

		expect(writer:GetDataToSave()).toEqual(5)
	end)

	it("should store a boolean save value (false is not treated as unset)", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(false)

		expect(writer:GetDataToSave()).toEqual(false)
	end)

	it("should deep-copy a frozen table snapshot rather than storing the reference", function()
		local writer = DataStoreWriter.new("test")
		local source = table.freeze({ coins = 5, gems = 3 })
		writer:SetSaveDataSnapshot(source)

		expect(writer:GetDataToSave()).toEqual({ coins = 5, gems = 3 })
		expect((writer:GetDataToSave() == source)).toEqual(false)
	end)

	it("should deep-copy nested tables inside the snapshot", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(deepFreeze({ stats = { hp = 10, mp = 5 } }))

		expect(writer:GetDataToSave()).toEqual({ stats = { hp = 10, mp = 5 } })
	end)

	it("should reject an unfrozen table snapshot", function()
		local writer = DataStoreWriter.new("test")

		expect(function()
			writer:SetSaveDataSnapshot({ coins = 5 })
		end).toThrow("saveDataSnapshot should be frozen")
	end)

	it("should store the delete token as a complete wipe", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(DataStoreDeleteToken)

		expect((writer:GetDataToSave() == DataStoreDeleteToken)).toEqual(true)
		expect(writer:IsCompleteWipe()).toEqual(true)
	end)
end)

describe("DataStoreWriter:IsCompleteWipe", function()
	it("should be false when unset", function()
		local writer = DataStoreWriter.new("test")
		expect(writer:IsCompleteWipe()).toEqual(false)
	end)

	it("should be false for a scalar save value", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(5)
		expect(writer:IsCompleteWipe()).toEqual(false)
	end)

	it("should be true only for the delete token", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(DataStoreDeleteToken)
		expect(writer:IsCompleteWipe()).toEqual(true)
	end)
end)

describe("DataStoreWriter:AddSubWriter / GetWriter / GetSubWritersMap", function()
	it("should register and retrieve a sub-writer by string name", function()
		local parent = DataStoreWriter.new("parent")
		local child = DataStoreWriter.new("child")
		parent:AddSubWriter("inventory", child)

		expect((parent:GetWriter("inventory") == child)).toEqual(true)
		expect((parent:GetSubWritersMap()["inventory"] == child)).toEqual(true)
	end)

	it("should return nil for an unknown sub-writer name", function()
		local parent = DataStoreWriter.new("parent")
		expect(parent:GetWriter("missing")).toBeNil()
	end)

	it("should error when adding two writers under the same name", function()
		local parent = DataStoreWriter.new("parent")
		parent:AddSubWriter("inventory", DataStoreWriter.new("a"))

		expect(function()
			parent:AddSubWriter("inventory", DataStoreWriter.new("b"))
		end).toThrow("Writer already exists for name")
	end)

	it("should error when adding a nil writer", function()
		local parent = DataStoreWriter.new("parent")
		expect(function()
			parent:AddSubWriter("inventory", nil)
		end).toThrow("Bad writer")
	end)

	it("should error when the name is neither string nor number", function()
		local parent = DataStoreWriter.new("parent")
		expect(function()
			parent:AddSubWriter({}, DataStoreWriter.new("child"))
		end).toThrow("Bad name")
	end)

	it("should accept a numeric name but leave it unreachable through GetWriter", function()
		-- Sharp edge: AddSubWriter permits number keys, yet GetWriter asserts a string name.
		local parent = DataStoreWriter.new("parent")
		local child = DataStoreWriter.new("child")
		parent:AddSubWriter(1, child)

		expect((parent:GetSubWritersMap()[1] == child)).toEqual(true)
		expect(function()
			parent:GetWriter(1)
		end).toThrow("Bad name")
	end)
end)

describe("DataStoreWriter:SetUserIdList / GetUserIdList", function()
	it("should round-trip a user id list", function()
		local writer = DataStoreWriter.new("test")
		writer:SetUserIdList({ 1, 2, 3 })

		expect(writer:GetUserIdList()).toEqual({ 1, 2, 3 })
	end)

	it("should return nil before a list is set", function()
		local writer = DataStoreWriter.new("test")
		expect(writer:GetUserIdList()).toBeNil()
	end)

	it("should allow clearing the list back to nil", function()
		local writer = DataStoreWriter.new("test")
		writer:SetUserIdList({ 1 })
		writer:SetUserIdList(nil)

		expect(writer:GetUserIdList()).toBeNil()
	end)

	it("should reject a non-table user id list", function()
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:SetUserIdList(5)
		end).toThrow("Bad userIdList")
	end)
end)

describe("DataStoreWriter:SetFullBaseDataSnapshot", function()
	it("should accept a frozen table", function()
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))
		end).never.toThrow()
	end)

	it("should reject an unfrozen table", function()
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:SetFullBaseDataSnapshot({ coins = 5 })
		end).toThrow("fullBaseDataSnapshot should be frozen")
	end)

	it("should reject the delete token", function()
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:SetFullBaseDataSnapshot(DataStoreDeleteToken)
		end).toThrow("fullBaseDataSnapshot should not be symbol")
	end)
end)

describe("DataStoreWriter:WriteMerge", function()
	it("should return the original unchanged when nothing is staged", function()
		local writer = DataStoreWriter.new("test")

		expect((writer:WriteMerge(5))).toEqual(5)
		expect((writer:WriteMerge(nil))).toBeNil()
		expect((writer:WriteMerge({ coins = 1 }))).toEqual({ coins = 1 })
	end)

	it("should return the delete token when the save is a complete wipe", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(DataStoreDeleteToken)

		expect((writer:WriteMerge({ coins = 1 }) == DataStoreDeleteToken)).toEqual(true)
	end)

	it("should replace the original entirely with a scalar save value", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(10)

		expect((writer:WriteMerge({ coins = 1 }))).toEqual(10)
		expect((writer:WriteMerge(nil))).toEqual(10)
	end)

	it("should merge a table save on top of the original, keeping untouched keys", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(table.freeze({ coins = 5 }))

		expect((writer:WriteMerge({ coins = 1, gems = 2 }))).toEqual({ coins = 5, gems = 2 })
	end)

	it("should remove a key when the save carries a delete token for it", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(table.freeze({ coins = DataStoreDeleteToken }))

		expect((writer:WriteMerge({ coins = 1, gems = 2 }))).toEqual({ gems = 2 })
	end)

	it("should swap a scalar original to a table when the save is a table", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(table.freeze({ coins = 5 }))

		expect((writer:WriteMerge(5))).toEqual({ coins = 5 })
	end)

	it("should treat an empty table save as a no-op merge", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(table.freeze({}))

		expect((writer:WriteMerge({ coins = 1 }))).toEqual({ coins = 1 })
	end)

	it("should not mutate the original table passed in", function()
		local writer = DataStoreWriter.new("test")
		writer:SetSaveDataSnapshot(table.freeze({ coins = 5 }))
		local original = { coins = 1, gems = 2 }
		writer:WriteMerge(original)

		expect(original).toEqual({ coins = 1, gems = 2 })
	end)
end)

describe("DataStoreWriter:WriteMerge with sub-writers", function()
	it("should merge a nested sub-writer's save into its key", function()
		local parent = DataStoreWriter.new("parent")
		local child = DataStoreWriter.new("child")
		child:SetSaveDataSnapshot(table.freeze({ sword = true }))
		parent:AddSubWriter("inventory", child)

		local result = parent:WriteMerge({ coins = 5, inventory = { shield = true } })
		expect(result).toEqual({ coins = 5, inventory = { shield = true, sword = true } })
	end)

	it("should remove the key when a sub-writer resolves to a delete token", function()
		local parent = DataStoreWriter.new("parent")
		local child = DataStoreWriter.new("child")
		child:SetSaveDataSnapshot(DataStoreDeleteToken)
		parent:AddSubWriter("inventory", child)

		local result = parent:WriteMerge({ coins = 5, inventory = { x = 1 } })
		expect(result).toEqual({ coins = 5 })
	end)

	it("should build up a table from a scalar original when sub-writers are present", function()
		local parent = DataStoreWriter.new("parent")
		local child = DataStoreWriter.new("child")
		child:SetSaveDataSnapshot(table.freeze({ a = 1 }))
		parent:AddSubWriter("sub", child)

		expect((parent:WriteMerge(5))).toEqual({ sub = { a = 1 } })
	end)
end)

describe("DataStoreWriter:ComputeDiffSnapshot", function()
	it("should emit only the changed key against the base", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5, gems = 3 }))

		expect((writer:ComputeDiffSnapshot({ coins = 5, gems = 10 }))).toEqual({ gems = 10 })
	end)

	it("should emit a delete token for a key removed from the incoming data", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))

		local diff = writer:ComputeDiffSnapshot({})
		expect((diff.coins == DataStoreDeleteToken)).toEqual(true)
	end)

	it("should emit a newly added key", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))

		expect((writer:ComputeDiffSnapshot({ coins = 5, gems = 1 }))).toEqual({ gems = 1 })
	end)

	it("should return nil when the incoming table matches the base", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))

		expect((writer:ComputeDiffSnapshot({ coins = 5 }))).toBeNil()
	end)

	it("should diff nested tables and emit only the changed leaf", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(deepFreeze({ stats = { hp = 10, mp = 5 } }))

		expect((writer:ComputeDiffSnapshot({ stats = { hp = 10, mp = 8 } }))).toEqual({ stats = { mp = 8 } })
	end)

	it("should return a frozen diff snapshot", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))

		expect((table.isfrozen(writer:ComputeDiffSnapshot({ coins = 10 })))).toEqual(true)
	end)

	it("should treat an empty incoming with no base or writers as a full delete", function()
		local writer = DataStoreWriter.new("test")

		expect((writer:ComputeDiffSnapshot({}) == DataStoreDeleteToken)).toEqual(true)
	end)

	it("should recurse into sub-writers, diffing against their own base", function()
		local parent = DataStoreWriter.new("parent")
		parent:SetFullBaseDataSnapshot(table.freeze({ coins = 5 }))

		local child = DataStoreWriter.new("child")
		child:SetFullBaseDataSnapshot(table.freeze({ sword = true }))
		parent:AddSubWriter("inv", child)

		local diff = parent:ComputeDiffSnapshot({ coins = 5, inv = { sword = true, shield = true } })
		expect(diff).toEqual({ inv = { shield = true } })
	end)

	it("should diff a scalar incoming against a scalar base", function()
		local writer = DataStoreWriter.new("test")
		writer:SetFullBaseDataSnapshot(5)

		expect((writer:ComputeDiffSnapshot(5))).toBeNil()
		expect((writer:ComputeDiffSnapshot(10))).toEqual(10)
	end)

	it("should reject the delete token as incoming", function()
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:ComputeDiffSnapshot(DataStoreDeleteToken)
		end).toThrow("Incoming value should not be DataStoreDeleteToken")
	end)

	it("should throw on a scalar incoming when the base is unset", function()
		-- Sharp edge: the unset sentinel is a symbol, and the scalar path asserts non-symbol.
		local writer = DataStoreWriter.new("test")
		expect(function()
			writer:ComputeDiffSnapshot(5)
		end).toThrow("original should not be symbol")
	end)
end)
