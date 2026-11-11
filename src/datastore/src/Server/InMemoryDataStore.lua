--!strict
--[=[
	A [DataStoreStage] root that lives entirely in memory: it is never backed by a Roblox datastore, so
	nothing it holds is ever written or read across sessions. Reads resolve to whatever has been staged in
	memory (defaults when unset) and writes stay local to this object, vanishing when it is destroyed.

	Every read/write/substore/observe method comes from [DataStoreStage] unchanged -- the base class computes
	its view purely from in-memory snapshots. The only thing a stage normally needs a parent for is
	[DataStoreStage.PromiseViewUpToDate] (loading its base layer from the datastore above it); a root has no
	parent, so this class resolves that immediately against its own view. That single override is the whole
	difference between this and [DataStore], which loads/saves through Roblox.

	Use it wherever code wants a real store surface for data that must not persist -- e.g. a throwaway session
	slot -- without paying for [DataStore]'s load, save, autosave, and session-locking machinery.

	```lua
	local store = InMemoryDataStore.new()
	store:Store("coins", 5)
	print(store:Load("coins"):Yield()) -- 5, never touches a datastore
	```

	@server
	@class InMemoryDataStore
]=]

local require = require(script.Parent.loader).load(script)

local DataStoreStage = require("DataStoreStage")
local Promise = require("Promise")

local InMemoryDataStore = setmetatable({}, DataStoreStage)
InMemoryDataStore.ClassName = "InMemoryDataStore"
InMemoryDataStore.__index = InMemoryDataStore

export type InMemoryDataStore =
	typeof(setmetatable({} :: {}, {} :: typeof({ __index = InMemoryDataStore })))
	& DataStoreStage.DataStoreStage

--[=[
	Constructs a new in-memory data store.

	@param loadName (string | number)? -- diagnostic name only (see [DataStoreStage.GetFullPath]); defaults to "InMemoryDataStore"
	@return InMemoryDataStore
]=]
function InMemoryDataStore.new(loadName: (string | number)?): InMemoryDataStore
	local self: InMemoryDataStore =
		setmetatable(DataStoreStage.new(loadName or "InMemoryDataStore") :: any, InMemoryDataStore)

	return self
end

--[=[
	The view is always exactly what has been staged in memory, so it is never out of date: there is no
	parent or datastore to sync from. Overriding this (the base class errors on a parentless stage) is what
	makes every inherited read work in-memory.

	@return Promise
]=]
function InMemoryDataStore.PromiseViewUpToDate(_self: InMemoryDataStore): Promise.Promise<()>
	return Promise.resolved()
end

--[=[
	A no-op that resolves: there is no backing datastore to flush to. Present so this is a drop-in root for
	code that expects to be able to call `:Save()` on its store.

	@return Promise
]=]
function InMemoryDataStore.Save(_self: InMemoryDataStore): Promise.Promise<()>
	return Promise.resolved()
end

return InMemoryDataStore
