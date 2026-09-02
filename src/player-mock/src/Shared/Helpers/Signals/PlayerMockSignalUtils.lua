--!strict
--[=[
	The events a mock stands in for, each backed by a same-named BindableEvent. A one-element path
	names a `Player` event (`"Chatted"`); a two-element one names an event of a client-global service
	(`"UserInputService.WindowFocused"`), which the mock keeps per-mock, a headless server having one
	of each while a test may hold several mocks.

	Paths are checked against the engine's own reflection, so a typo errors instead of returning a
	signal that can never fire.

	Use [PlayerMock.getSignal] and [PlayerMock.fireSignal].

	@class PlayerMockSignalUtils
]=]

local require = require(script.Parent.loader).load(script)

local InstancePathUtils = require("InstancePathUtils")
local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockReflectionUtils = require("PlayerMockReflectionUtils")
local PlayerMockUtils = require("PlayerMockUtils")

local PlayerMockSignalUtils = {}

--[=[
	Returns the genuine native signal for events the mock's backing Folder inherits from `Instance`,
	otherwise a `BindableEvent`-backed stand-in.

	Use [PlayerMock.getSignal].

	@param player Player -- must be a PlayerMock
	@param eventPath InstancePathTableLike -- `"Chatted"` or `"UserInputService.WindowFocused"`
	@return RBXScriptSignal
]=]
function PlayerMockSignalUtils.getSignal(
	player: Player,
	eventPath: InstancePathUtils.InstancePathTableLike
): RBXScriptSignal
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(eventPath), "Bad eventPath")
	assert(PlayerMockSignalUtils._isEvent(eventPath))

	local pathTable = InstancePathUtils.toPathTable(eventPath)

	-- Only a `Player` event can be one the backing Folder really has; a service event is never a
	-- member of the mock itself, however the mock is where its backing lives.
	if #pathTable == 1 then
		local nativeSignal = PlayerMockReflectionUtils.findNativeSignal(player, pathTable[1])
		if nativeSignal ~= nil then
			return nativeSignal
		end
	end

	local backingName = PlayerMockSignalUtils._getBackingName(pathTable)

	return PlayerMockSignalUtils._getOrCreateSignalBindable(player, backingName).Event
end

--[=[
	Fires the stand-in a consumer connected through [PlayerMockSignalUtils.getSignal] as if the engine
	had fired the real event.

	Use [PlayerMock.fireSignal].

	@param player Player -- must be a PlayerMock
	@param eventPath InstancePathTableLike -- `"Chatted"` or `"UserInputService.WindowFocused"`
	@param ... any -- Event arguments delivered to connected handlers.
]=]
function PlayerMockSignalUtils.fireSignal(
	player: Player,
	eventPath: InstancePathUtils.InstancePathTableLike,
	...: any
): ()
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(InstancePathUtils.isInstancePathTableLike(eventPath), "Bad eventPath")
	assert(PlayerMockSignalUtils._isEvent(eventPath))

	local pathTable = InstancePathUtils.toPathTable(eventPath)

	if #pathTable == 1 and PlayerMockReflectionUtils.findNativeSignal(player, pathTable[1]) ~= nil then
		error(string.format("%q is a native signal only the engine fires", pathTable[1]), 2)
	end

	-- No backing means no listeners ever connected. Not creating one here also keeps this safe
	-- mid-teardown, when parenting a new child would fail.
	local existing = (player :: Instance):FindFirstChild(PlayerMockSignalUtils._getBackingName(pathTable))
	if existing ~= nil then
		(existing :: BindableEvent):Fire(...)
	end
end

function PlayerMockSignalUtils._isEvent(eventPath: InstancePathUtils.InstancePathTableLike): (boolean, string?)
	local pathTable = InstancePathUtils.toPathTable(eventPath)
	local path = InstancePathUtils.fromPathTable(pathTable)

	if #pathTable == 1 then
		if PlayerMockReflectionUtils.isClassEvent("Player", path) then
			return true
		end

		return false, string.format("%q is not an event of Player", path)
	elseif #pathTable == 2 then
		local className, eventName = pathTable[1], pathTable[2]
		if not PlayerMockReflectionUtils.isClass(className) then
			return false, string.format("%q names no class the engine reflects", className)
		end

		-- Only a service is a singleton the mock has cause to keep its own copy of; anything else is
		-- an instance the test already holds and can connect to directly.
		if not PlayerMockReflectionUtils.isService(className) then
			return false, string.format("%q is not a service", className)
		end

		if not PlayerMockReflectionUtils.isClassEvent(className, eventName) then
			return false, string.format("%q is not an event of %s", eventName, className)
		end

		return true
	end

	return false, string.format("%q is neither a Player event nor a Service.Event path", path)
end

-- Instance names cannot hold the path separator, so a service path flattens onto an underscore. A
-- one-element path is its own backing name, keeping a `Player` event on its same-named BindableEvent.
function PlayerMockSignalUtils._getBackingName(pathTable: { string }): string
	return PlayerMockConstants.SIGNAL_NAME_PREFIX .. table.concat(pathTable, "_")
end

function PlayerMockSignalUtils._getOrCreateSignalBindable(player: Player, backingName: string): BindableEvent
	local instance = player :: Instance

	local existing = instance:FindFirstChild(backingName)
	if existing ~= nil then
		return existing :: BindableEvent
	end

	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = backingName
	bindableEvent.Parent = instance
	return bindableEvent
end

return PlayerMockSignalUtils
