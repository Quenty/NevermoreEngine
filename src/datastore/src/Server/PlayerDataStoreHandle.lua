--!strict
--[=[
	A borrowed [DataStore] for a player, and the obligation to put it back.

	Opening a store for a player who is not in this server takes their session lock, which kicks them
	from wherever they were playing. Until that lock is dropped again they cannot rejoin, so releasing
	it is the part that matters -- and a release the caller has to remember to perform is one that
	eventually gets missed on an error path.

	Handing back a handle makes it a [Maid]-shaped obligation instead: give it to a maid, or destroy
	it, and the session is released once nothing is using it. Destroying twice is safe.

	Handles are counted, so three systems loading the same player each get their own and the session
	survives until the last one is destroyed.

	A player in this server is not represented by a handle -- their session is owned by the join and
	leave path, which reaches removal from several directions a handle could not model safely. So
	destroying a handle never closes a live player's session; it only releases one this tooling
	opened on behalf of someone absent.

	```lua
	local handle = manager:PromiseDataStoreHandle(userId):Yield()
	local data = handle:GetDataStore():LoadAll({}):Yield()
	handle:Destroy()
	```

	@server
	@class PlayerDataStoreHandle
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")

local PlayerDataStoreHandle = {}
PlayerDataStoreHandle.ClassName = "PlayerDataStoreHandle"
PlayerDataStoreHandle.__index = PlayerDataStoreHandle

export type PlayerDataStoreHandle = typeof(setmetatable(
	{} :: {
		_dataStore: DataStore.DataStore?,
		_release: (() -> ())?,
	},
	{} :: typeof({ __index = PlayerDataStoreHandle })
))

--[=[
	Constructs a new handle over a datastore.

	@param dataStore DataStore
	@param release (() -> ())? -- invoked on destroy, when this handle is the one that borrowed the store
	@return PlayerDataStoreHandle
]=]
function PlayerDataStoreHandle.new(dataStore: DataStore.DataStore, release: (() -> ())?): PlayerDataStoreHandle
	local self: PlayerDataStoreHandle = setmetatable({} :: any, PlayerDataStoreHandle)

	self._dataStore = assert(dataStore, "No dataStore")
	self._release = release

	return self
end

--[=[
	Returns whether the value is a handle.

	@param value any
	@return boolean
]=]
function PlayerDataStoreHandle.isPlayerDataStoreHandle(value: any): boolean
	return type(value) == "table" and getmetatable(value) == PlayerDataStoreHandle
end

--[=[
	Returns the datastore this handle holds. Errors once destroyed, since the session behind it may
	already be closed.

	@return DataStore
]=]
function PlayerDataStoreHandle.GetDataStore(self: PlayerDataStoreHandle): DataStore.DataStore
	-- Bound to one value rather than returned straight out of the assert, which would hand back its
	-- message as a second return and quietly widen every call site into a multiple-value expression.
	local dataStore = self._dataStore
	assert(dataStore, "Handle is destroyed")

	return dataStore
end

--[=[
	Drops this handle's reference to the session. The session itself is released once no handle and
	no player in this server is still holding it.
]=]
function PlayerDataStoreHandle.Destroy(self: PlayerDataStoreHandle): ()
	local release = self._release

	self._dataStore = nil
	self._release = nil

	if release then
		release()
	end
end

return PlayerDataStoreHandle
