--!strict
--[=[
	Tracks whether a player owns a given asset. Ownership resolves from an async cloud
	query (see [PlayerAssetOwnershipTracker:SetQueryOwnershipCallback]) plus session
	purchases, with an optional local override layered on top.

	The override (see [PlayerAssetOwnershipTracker:SetOwnershipOverride]) is an authoritative layer:
	when set it wins over the cloud query and session purchases, forcing ownership on (`true`) or off
	(`false`). It is stored in a server-owned [JSONAttributeValue] on the player that Roblox
	replicates read-only to clients, so every realm applies the same overrides but only the server
	can assign them -- a player can never grant themselves ownership.

	@class PlayerAssetOwnershipTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigPicker = require("GameConfigPicker")
local JSONAttributeValue = require("JSONAttributeValue")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local ObservableSet = require("ObservableSet")
local PlayerProductOwnershipOverrideUtils = require("PlayerProductOwnershipOverrideUtils")
local Promise = require("Promise")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local PlayerAssetOwnershipTracker = setmetatable({}, BaseObject)
PlayerAssetOwnershipTracker.ClassName = "PlayerAssetOwnershipTracker"
PlayerAssetOwnershipTracker.__index = PlayerAssetOwnershipTracker

export type PlayerAssetOwnershipTracker =
	typeof(setmetatable(
		{} :: {
			_player: Player,
			_configPicker: any,
			_assetType: GameConfigAssetTypes.GameConfigAssetType,
			_marketTracker: any,
			_ownershipCallback: ValueObject.ValueObject<(number) -> Promise.Promise<boolean> | nil>,
			_ownedAssetIdSet: ObservableSet.ObservableSet<number>,
			-- Typed `any` (not ObservableMap<number, boolean>) to keep this class's intersection
			-- type small enough for the Luau solver; accessed only through `self: any` methods.
			_ownershipOverrides: any,
			-- Server-owned JSONAttributeValue holding the replicated override map, plus the last map
			-- applied to _ownershipOverrides (for diffing on reconcile). Both `any` for the same
			-- solver reason as _ownershipOverrides.
			_overrideAttribute: any,
			_appliedOverrideState: any,
			_assetOwnershipPromiseCache: { [number]: Promise.Promise<boolean> | boolean },
		},
		{} :: typeof({ __index = PlayerAssetOwnershipTracker })
	))
	& BaseObject.BaseObject

function PlayerAssetOwnershipTracker.new(
	player: Player,
	configPicker: GameConfigPicker.GameConfigPicker,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	marketTracker: any
): PlayerAssetOwnershipTracker
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local self: PlayerAssetOwnershipTracker = setmetatable(BaseObject.new() :: any, PlayerAssetOwnershipTracker)

	self._player = assert(player, "No player")
	self._configPicker = assert(configPicker, "No configPicker")
	self._assetType = assert(assetType, "No assetType")
	self._marketTracker = assert(marketTracker, "No marketTracker")

	self._ownershipCallback = self._maid:Add(ValueObject.new(nil))
	self._ownedAssetIdSet = self._maid:Add(ObservableSet.new())
	self._ownershipOverrides = self._maid:Add(ObservableMap.new())

	self._appliedOverrideState = {}
	self._overrideAttribute =
		JSONAttributeValue.new(self._player, PlayerProductOwnershipOverrideUtils.attributeName(assetType), nil)

	self._assetOwnershipPromiseCache = {}

	self._maid:GiveTask(self._marketTracker.Purchased:Connect(function(idOrKey)
		self:SetOwnership(idOrKey, true)
	end))

	-- Apply the replicated override map to _ownershipOverrides. Observe() emits synchronously on
	-- subscribe (current value) and again on every change -- including a client receiving the
	-- server's replicated write -- so this covers both the initial reconcile and later updates.
	self._maid:GiveTask(self._overrideAttribute:Observe():Subscribe(function()
		self:_reconcileOverrides()
	end))

	return self
end

--[=[
	Sets the callback which will query ownership
	@param promiseOwnsAsset function
]=]
function PlayerAssetOwnershipTracker:SetQueryOwnershipCallback(promiseOwnsAsset: (any) -> Promise.Promise<boolean>?): ()
	assert(type(promiseOwnsAsset) == "function" or promiseOwnsAsset == nil, "Bad promiseOwnsAsset")

	if self._ownershipCallback.Value == promiseOwnsAsset then
		return
	end

	self._assetOwnershipPromiseCache = {}
	self._ownershipCallback.Value = promiseOwnsAsset
end

function PlayerAssetOwnershipTracker:_promiseQueryAssetId(assetId: number): Promise.Promise<boolean>?
	assert(type(assetId) == "number", "Bad assetId")

	local promiseOwnershipCallback = self._ownershipCallback.Value
	if not promiseOwnershipCallback then
		return Promise.rejected(
			string.format(
				"[PlayerAssetOwnershipTracker] - Cannot query ownership for assetType %q - No ownership callback set",
				tostring(self._assetType)
			)
		)
	end

	if self._assetOwnershipPromiseCache[assetId] ~= nil then
		if Promise.isPromise(self._assetOwnershipPromiseCache[assetId]) then
			return self._assetOwnershipPromiseCache[assetId]
		else
			return Promise.resolved(self._assetOwnershipPromiseCache[assetId])
		end
	end

	local promise = promiseOwnershipCallback(assetId)
	assert(Promise.isPromise(promise), "Expected promise from callack")

	promise = self._maid:GivePromise(promise)

	promise:Then(function(ownsItem)
		self._assetOwnershipPromiseCache[assetId] = ownsItem

		-- Cache this stuff
		if ownsItem then
			self:SetOwnership(assetId, true)
		end
	end)

	self._assetOwnershipPromiseCache[assetId] = promise

	return promise
end

--[=[
	Sets the players ownership of a the asset

	@param idOrKey number
	@param ownsAsset boolean
]=]
function PlayerAssetOwnershipTracker:SetOwnership(idOrKey, ownsAsset: boolean): ()
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")
	assert(type(ownsAsset) == "boolean", "Bad ownsAsset")

	local assetId = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if not assetId then
		warn(string.format("[PlayerAssetOwnershipTracker.SetOwnership] - Nothing with key %q", tostring(idOrKey)))
		return
	end

	if self._ownedAssetIdSet:Contains(assetId) then
		return
	end

	self._ownedAssetIdSet:Add(assetId)
end

--[=[
	Sets a server-authoritative override for the player's ownership of the asset. When set, the
	override wins over the cloud query and any session purchase, forcing ownership on (`true`) or off
	(`false`). Passing `nil` clears the override so ownership falls back to the cloud query again
	(equivalent to [PlayerAssetOwnershipTracker.ClearOwnershipOverride]).

	The override is published into a replicated attribute and applied on every realm, so it drives
	client-side ownership-gated UI. Only the server can assign it: the client-facing service exposes
	no setter and [GameProductService.SetPlayerOwnershipOverride] guards the server realm, so a player
	can never grant themselves ownership. Callers should go through that service, never here directly.

	@param idOrKey number | string
	@param ownsAsset boolean?
]=]
-- `self: any` here (and on ClearOwnershipOverride / the observe helpers) keeps the Luau solver
-- from renormalizing the full PlayerAssetOwnershipTracker & BaseObject intersection at every
-- `self:...` access, which otherwise trips "Code is too complex to typecheck" for this module.
function PlayerAssetOwnershipTracker.SetOwnershipOverride(self: any, idOrKey, ownsAsset: boolean?): ()
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")
	assert(type(ownsAsset) == "boolean" or ownsAsset == nil, "Bad ownsAsset")

	local assetId = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if not assetId then
		warn(
			string.format("[PlayerAssetOwnershipTracker.SetOwnershipOverride] - Nothing with key %q", tostring(idOrKey))
		)
		return
	end

	-- Resolve to a stable asset id so the override applies to the same key every realm observes.
	local state = PlayerProductOwnershipOverrideUtils.sanitizeState(self._overrideAttribute.Value)
	if ownsAsset == nil then
		state[tostring(assetId)] = nil
	else
		state[tostring(assetId)] = ownsAsset
	end
	if next(state) == nil then
		-- Drop the attribute entirely so "no overrides" is the absence of the attribute.
		self._overrideAttribute.Value = nil
	else
		self._overrideAttribute.Value = state
	end

	-- Apply immediately rather than waiting on the (possibly deferred) attribute-changed signal.
	-- _reconcileOverrides diffs against the applied state, so the later Observe callback is a no-op.
	self:_reconcileOverrides()
end

-- Applies the replicated override map onto _ownershipOverrides, adding/updating present entries and
-- removing ones that are gone. Runs on every realm from the attribute observer.
function PlayerAssetOwnershipTracker._reconcileOverrides(self: any): ()
	local desiredState = PlayerProductOwnershipOverrideUtils.sanitizeState(self._overrideAttribute.Value)

	for key, ownsAsset in desiredState do
		if self._appliedOverrideState[key] ~= ownsAsset then
			self._ownershipOverrides:Set(tonumber(key) or key, ownsAsset)
		end
	end

	for key in self._appliedOverrideState do
		if desiredState[key] == nil then
			self._ownershipOverrides:Remove(tonumber(key) or key)
		end
	end

	self._appliedOverrideState = desiredState
end

--[=[
	Clears any local ownership override for the asset, so ownership falls back to the cloud
	query. Equivalent to `SetOwnershipOverride(idOrKey, nil)`.

	@param idOrKey number | string
]=]
function PlayerAssetOwnershipTracker.ClearOwnershipOverride(self: any, idOrKey): ()
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	self:SetOwnershipOverride(idOrKey, nil)
end

--[=[
	Promises true if the user owns the asset and false otherwise

	@param idOrKey string | number
	@return Promise<boolean>
]=]
function PlayerAssetOwnershipTracker:PromiseOwnsAsset(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	local assetId = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if assetId then
		-- Local override wins over the cloud query and session purchases.
		local override = self._ownershipOverrides:Get(assetId)
		if override ~= nil then
			return Promise.resolved(override)
		end

		if self._ownedAssetIdSet:Contains(assetId) then
			return Promise.resolved(true)
		end
	else
		return Promise.rejected(
			string.format("[PlayerAssetOwnershipTracker.PromiseOwnsAsset] - Nothing with key %q", tostring(idOrKey))
		)
	end

	-- Check actual callback querying Roblox
	local promise = self:_promiseQueryAssetId(assetId)
	if promise then
		return promise
	else
		-- Assume no ownership
		return Promise.resolved(false)
	end
end

--[=[
	Observes whether the player owns the asset or not
	@param idOrKey number | number
	@return Observable<boolean>
]=]
function PlayerAssetOwnershipTracker:ObserveOwnsAsset(idOrKey): Observable.Observable<boolean>
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	-- TODO: Get rid of several concepts here, including well known assets, attributes, and more

	if type(idOrKey) == "string" then
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			topMaid:GiveTask(self._configPicker:ObserveToAssetIdBrio(self._assetType, idOrKey):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid, assetId = brio:ToMaidAndValue()
				maid:GiveTask(self:_observeOwnsAssetId(assetId):Subscribe(function(value)
					sub:Fire(value)
				end))
			end))

			return topMaid
		end) :: any
	elseif type(idOrKey) == "number" then
		return self:_observeOwnsAssetId(idOrKey)
	else
		error("Bad idOrKey")
	end
end

--[=[
	Observes ownership of a resolved numeric asset id, layering the local override on top of
	the cloud query. When an override is present it wins and short-circuits the query; when it
	is cleared, ownership falls back to the cloud query and owned-asset set.

	@param assetId number
	@return Observable<boolean>
]=]
-- Private helpers take `self: any` on purpose: typing `self` as the full
-- PlayerAssetOwnershipTracker & BaseObject intersection makes the Luau solver renormalize it
-- at every `self:...` access here, which trips "Code is too complex to typecheck".
function PlayerAssetOwnershipTracker._observeOwnsAssetId(self: any, assetId: number): Observable.Observable<boolean>
	assert(type(assetId) == "number", "Bad assetId")

	return self._ownershipOverrides:ObserveAtKey(assetId):Pipe({
		Rx.switchMap(function(override)
			if override ~= nil then
				return Rx.of(override) :: any
			end

			return self:_observeBaseOwnsAssetId(assetId)
		end) :: any,
	}) :: any
end

--[=[
	Observes ownership of a numeric asset id from the cloud query and owned-asset set only,
	without applying any override. Only fires once ownership status has been resolved.

	@param assetId number
	@return Observable<boolean>
]=]
function PlayerAssetOwnershipTracker._observeBaseOwnsAssetId(self: any, assetId: number): Observable.Observable<boolean>
	assert(type(assetId) == "number", "Bad assetId")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GivePromise(self:_promiseQueryAssetId(assetId)):Then(function()
			-- Only fire once we find ownership status
			maid:GiveTask(self._ownedAssetIdSet:ObserveContains(assetId):Subscribe(function(value)
				sub:Fire(value)
			end))
		end)

		return maid
	end) :: any
end

return PlayerAssetOwnershipTracker
