--!strict
--[=[
	The native properties a mock stands in for, each backed by a same-named attribute. A one-element
	path names a `Player` property (`"UserId"`); a two-element one names a member of a client-global
	service (`"GuiService.SelectedObject"`), which the mock keeps per-mock, a headless server having
	one of each while a test may hold several mocks.

	Members an attribute cannot hold are bridged: EnumItems round-trip through their `.Name`,
	Instances through an ObjectValue child. Paths are checked against the engine's own reflection, so
	a typo errors instead of reading back a value nothing will ever write.

	Use [PlayerMock.read], [PlayerMock.write] and [PlayerMock.getPropertyChangedSignal].

	@class PlayerMockPropertyUtils
]=]

local require = require(script.Parent.loader).load(script)

local InstancePathUtils = require("InstancePathUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockReflectionUtils = require("PlayerMockReflectionUtils")
local PlayerMockSignalUtils = require("PlayerMockSignalUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockPropertyUtils = {}

type PropertySpec = {
	default: any,
	instanceValued: boolean?,
	encode: ((any) -> any)?,
	decode: ((any) -> any)?,
}

-- Defaults are pre-authored, a `Player` not being `Instance.new`-able to reflect them off. An entry
-- only describes how a member is backed and what it answers when unset -- reflection decides which
-- paths exist at all, so a member absent here still reads and writes, on a plain attribute.
local PROPERTIES: { [string]: PropertySpec } = {
	UserId = { default = 0 },
	DisplayName = { default = "" },
	MembershipType = {
		default = Enum.MembershipType.None,
		encode = function(value: any): string
			return (value :: EnumItem).Name
		end,
		decode = function(value: any): EnumItem
			return (Enum.MembershipType :: any)[value]
		end,
	},
	AccountAge = { default = 0 },
	HasVerifiedBadge = { default = false },
	FollowUserId = { default = 0 },
	-- `Player:HasAppearanceLoaded()` on a real Player, but a zero-arg boolean getter reads the same.
	HasAppearanceLoaded = { default = false },
	Character = { instanceValued = true }, -- default nil, like a real Player before spawn
	RespawnLocation = { instanceValued = true }, -- default nil; checkpoint spawn stand-in

	-- The engine refuses `GuiService.SelectedObject = obj` on a headless server, there being no
	-- PlayerGui to select within.
	["GuiService.SelectedObject"] = { instanceValued = true },
}

--[=[
	Seeds every modelled property on a fresh mock, from `overrides` (keyed by property path) or the
	pre-authored default. Paths with no default seed nothing, which is how the Instance-valued members
	stay nil the way a real `Player`'s do before spawn.

	Use [PlayerMock.new].

	@param player Player -- must be a PlayerMock
	@param overrides { [string]: any }? -- Per-property seed values, keyed by property path.
]=]
function PlayerMockPropertyUtils.seedProperties(player: Player, overrides: { [string]: any }?): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	for propertyPath, spec in PROPERTIES do
		local value: any
		if overrides and overrides[propertyPath] ~= nil then
			value = overrides[propertyPath]
		elseif propertyPath == "DisplayName" then
			value = player.Name
		else
			value = spec.default
		end

		if value ~= nil then
			PlayerMockPropertyUtils.write(player, propertyPath, value)
		end
	end
end

--[=[
	Returns the seeded backing attribute, or the pre-authored default when unset.

	Use [PlayerMock.read].

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@return any
]=]
function PlayerMockPropertyUtils.read(player: Player, propertyPath: InstancePathUtils.InstancePathTableLike): any
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(propertyPath), "Bad propertyPath")
	assert(PlayerMockPropertyUtils._isProperty(propertyPath))

	local pathTable = InstancePathUtils.toPathTable(propertyPath)
	local backingName = PlayerMockPropertyUtils._getBackingName(pathTable)
	local spec = PlayerMockPropertyUtils._findSpec(pathTable)

	if spec and spec.instanceValued then
		local backing = PlayerMockPropertyUtils._findPropertyObjectValue(player, backingName)
		return if backing ~= nil then backing.Value else spec.default
	end

	local raw = player:GetAttribute(backingName)
	if raw == nil then
		return if spec then spec.default else nil
	end
	if spec and spec.decode then
		return spec.decode(raw)
	end

	return raw
end

--[=[
	Writing `Character = nil` carries the engine's despawn semantics.

	Use [PlayerMock.write].

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@param value any
]=]
function PlayerMockPropertyUtils.write(
	player: Player,
	propertyPath: InstancePathUtils.InstancePathTableLike,
	value: any
): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(propertyPath), "Bad propertyPath")
	assert(PlayerMockPropertyUtils._isProperty(propertyPath))

	local pathTable = InstancePathUtils.toPathTable(propertyPath)
	local backingName = PlayerMockPropertyUtils._getBackingName(pathTable)
	local spec = PlayerMockPropertyUtils._findSpec(pathTable)

	if spec and spec.instanceValued then
		if not (value == nil or typeof(value) == "Instance") then
			error(string.format("Bad value for Instance-valued %s", InstancePathUtils.fromPathTable(pathTable)), 2)
		end

		local objectValue = PlayerMockPropertyUtils._getOrCreatePropertyObjectValue(player, backingName)
		local oldValue = objectValue.Value

		-- The engine's Character setter despawns on nil: CharacterRemoving -> nil -> destroy.
		-- Assigning a *different* model does not remove the old one (the morph pattern destroys it).
		if backingName == "Character" and value == nil and oldValue ~= nil then
			PlayerMockSignalUtils.fireSignal(player, "CharacterRemoving", oldValue)
			objectValue.Value = nil
			oldValue:Destroy()
			return
		end

		objectValue.Value = value
		return
	end

	local encoded = if spec and spec.encode then spec.encode(value) else value

	local instance = player :: Instance
	instance:SetAttribute(backingName, encoded)
end

--[=[
	Returns the backing attribute's changed signal, or the backing ObjectValue's Value-changed signal
	for Instance-valued members.

	Use [PlayerMock.getPropertyChangedSignal].

	@param player Player -- must be a PlayerMock
	@param propertyPath InstancePathTableLike -- `"UserId"` or `"GuiService.SelectedObject"`
	@return RBXScriptSignal
]=]
function PlayerMockPropertyUtils.getPropertyChangedSignal(
	player: Player,
	propertyPath: InstancePathUtils.InstancePathTableLike
): RBXScriptSignal
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(propertyPath), "Bad propertyPath")
	assert(PlayerMockPropertyUtils._isProperty(propertyPath))

	local pathTable = InstancePathUtils.toPathTable(propertyPath)
	local backingName = PlayerMockPropertyUtils._getBackingName(pathTable)
	local spec = PlayerMockPropertyUtils._findSpec(pathTable)

	if spec and spec.instanceValued then
		return PlayerMockPropertyUtils._getOrCreatePropertyObjectValue(player, backingName)
			:GetPropertyChangedSignal("Value")
	end

	return player:GetAttributeChangedSignal(backingName)
end

function PlayerMockPropertyUtils._isProperty(propertyPath: InstancePathUtils.InstancePathTableLike): (boolean, string?)
	local pathTable = InstancePathUtils.toPathTable(propertyPath)
	local path = InstancePathUtils.fromPathTable(pathTable)

	if #pathTable == 1 then
		-- The modelled table comes first because it carries members reflection does not report as
		-- properties, like the `Player:HasAppearanceLoaded()` getter a mock stands in for with a value.
		if PROPERTIES[path] ~= nil or PlayerMockReflectionUtils.isClassProperty("Player", path) then
			return true
		end

		return false, string.format("%q is not a property of Player", path)
	elseif #pathTable == 2 then
		local className, propertyName = pathTable[1], pathTable[2]
		if not PlayerMockReflectionUtils.isClass(className) then
			return false, string.format("%q names no class the engine reflects", className)
		end

		-- Only a service is a singleton the mock has cause to keep its own copy of; anything else is
		-- an instance the test already holds and can read directly.
		if not PlayerMockReflectionUtils.isService(className) then
			return false, string.format("%q is not a service", className)
		end

		-- No modelled escape hatch here: a service member has to be one the real service has, or a
		-- mock would answer for a call production could never have made.
		if not PlayerMockReflectionUtils.isClassProperty(className, propertyName) then
			return false, string.format("%q is not a property of %s", propertyName, className)
		end

		return true
	end

	return false, string.format("%q is neither a Player property nor a Service.Property path", path)
end

function PlayerMockPropertyUtils._findSpec(pathTable: { string }): PropertySpec?
	return PROPERTIES[InstancePathUtils.fromPathTable(pathTable)]
end

-- Attribute names cannot hold the path separator, so a service path flattens onto an underscore. A
-- one-element path is its own backing name, keeping a `Player` property on its same-named attribute.
function PlayerMockPropertyUtils._getBackingName(pathTable: { string }): string
	return table.concat(pathTable, "_")
end

function PlayerMockPropertyUtils._findPropertyObjectValue(player: Player, backingName: string): ObjectValue?
	return player:FindFirstChild(PlayerMockConstants.PROPERTY_OBJECT_NAME_PREFIX .. backingName) :: ObjectValue?
end

function PlayerMockPropertyUtils._getOrCreatePropertyObjectValue(player: Player, backingName: string): ObjectValue
	local existing = PlayerMockPropertyUtils._findPropertyObjectValue(player, backingName)
	if existing ~= nil then
		return existing
	end

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = PlayerMockConstants.PROPERTY_OBJECT_NAME_PREFIX .. backingName
	objectValue.Parent = player :: Instance
	return objectValue
end

return PlayerMockPropertyUtils
