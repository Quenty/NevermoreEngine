--!strict
--[=[
	A player's save slots opened without that player, and the obligation to close them again.

	Wraps a borrowed [PlayerDataStoreHandle] and a [HasSaveSlotsDataStore] built over it, so admin
	tooling can act on someone who is not in this server. Destroying this releases the session -- see
	[PlayerDataStoreHandle] for why that matters, and [SaveSlotService.PromiseOfflineSaveSlots] for
	how one is opened.

	:::warning
	Opening this **steals the player's session lock**, which kicks them from wherever they were
	playing. It is for admin tooling acting on an absent player; never open one for a player who is
	in this server -- use their bound [HasSaveSlots] instead, or you will be writing to a second,
	stale copy of their data.
	:::

	The value objects backing the slot state are detached rather than replicated: there is no player
	to replicate to, and the slot roster stays unparented for the same reason.

	```lua
	local offline = saveSlotService:PromiseOfflineSaveSlots(userId):Yield()
	local slots = offline:GetSlotsDataStore()
	print(slots:GetSlotList())
	offline:Destroy()
	```

	@server
	@class OfflineSaveSlots
]=]

local require = require(script.Parent.loader).load(script)

local HasSaveSlotsDataStore = require("HasSaveSlotsDataStore")
local Maid = require("Maid")
local Promise = require("Promise")
local SaveSlotCodeUtils = require("SaveSlotCodeUtils")
local ValueObject = require("ValueObject")

--[=[
	@interface OfflineSaveSlotsOptions
	.SharedDataStoreService any -- SaveSlotSharedDataStoreService
	.MaxSlotCount number
	.CodeGenerator SaveSlotCodeUtils.CodeGenerator?
	.UserId number?
	.UserName string?
	@within OfflineSaveSlots
]=]
export type OfflineSaveSlotsOptions = {
	SharedDataStoreService: any,
	MaxSlotCount: number,
	CodeGenerator: SaveSlotCodeUtils.CodeGenerator?,
	UserId: number?,
	UserName: string?,
}

local OfflineSaveSlots = {}
OfflineSaveSlots.ClassName = "OfflineSaveSlots"
OfflineSaveSlots.__index = OfflineSaveSlots

export type OfflineSaveSlots = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_handle: any,
		_slotsDataStore: any,
	},
	{} :: typeof({ __index = OfflineSaveSlots })
))

--[=[
	Builds the slot system over a borrowed datastore handle. Takes ownership of the handle: destroying
	this destroys it.

	@param handle PlayerDataStoreHandle
	@param options OfflineSaveSlotsOptions
	@return OfflineSaveSlots
]=]
function OfflineSaveSlots.new(handle: any, options: OfflineSaveSlotsOptions): OfflineSaveSlots
	local self: OfflineSaveSlots = setmetatable({} :: any, OfflineSaveSlots)

	self._handle = assert(handle, "No handle")
	assert(options, "No options")

	self._maid = Maid.new()

	-- Bound rather than asserted inline: assert returns its message as a second value, which
	-- ValueObject.new would take as a type check.
	local maxSlotCount = options.MaxSlotCount
	assert(type(maxSlotCount) == "number", "No MaxSlotCount")

	local slotsDataStore = HasSaveSlotsDataStore.new(Promise.resolved(handle:GetDataStore()), {
		ActiveSlotId = self._maid:Add(ValueObject.new(nil)),
		LastActiveSlotId = self._maid:Add(ValueObject.new(nil)),
		ActiveTransferableEphemeralKey = self._maid:Add(ValueObject.new(nil)),
		MaxSlotCount = self._maid:Add(ValueObject.new(maxSlotCount)),
		SharedDataStoreService = options.SharedDataStoreService,
		-- No parent: there is nobody to replicate the roster to.
		-- No pre-select veto either: those callbacks are written against a live player.
		UserId = options.UserId,
		UserName = options.UserName,
		-- An admin editing a slot from a console is not someone playing it, so no play session is
		-- ever begun and nothing accrues into TimePlayed or PlayCount.
		TrackPlaytime = false,
	})

	if options.CodeGenerator then
		slotsDataStore:SetCodeGenerator(options.CodeGenerator)
	end

	self._slotsDataStore = slotsDataStore

	return self
end

--[=[
	Returns whether the value is an OfflineSaveSlots.

	@param value any
	@return boolean
]=]
function OfflineSaveSlots.isOfflineSaveSlots(value: any): boolean
	return type(value) == "table" and getmetatable(value) == OfflineSaveSlots
end

--[=[
	Resolves once the slots have loaded from the datastore.

	@return Promise
]=]
function OfflineSaveSlots.PromiseSlotsLoaded(self: OfflineSaveSlots): Promise.Promise<any>
	return self._slotsDataStore:PromiseSlotsLoaded()
end

--[=[
	Returns the slot system, a [HasSaveSlotsDataStore]. Valid until this is destroyed.

	@return HasSaveSlotsDataStore
]=]
function OfflineSaveSlots.GetSlotsDataStore(self: OfflineSaveSlots): any
	-- Bound before asserting, so the assert's message does not ride along as a second return value.
	local slotsDataStore = self._slotsDataStore
	assert(slotsDataStore, "Destroyed")

	return slotsDataStore
end

--[=[
	Tears the slot system down and releases the borrowed session, which saves and unlocks it so the
	player can rejoin. Destroying twice is safe.
]=]
function OfflineSaveSlots.Destroy(self: OfflineSaveSlots): ()
	local slotsDataStore = self._slotsDataStore
	local handle = self._handle

	self._slotsDataStore = nil
	self._handle = nil

	-- Order matters: the slot system writes into the datastore the handle owns, so it has to be torn
	-- down before the handle releases -- which is what saves and unlocks the session.
	if slotsDataStore then
		slotsDataStore:Destroy()
	end

	self._maid:DoCleaning()

	if handle then
		handle:Destroy()
	end
end

return OfflineSaveSlots
