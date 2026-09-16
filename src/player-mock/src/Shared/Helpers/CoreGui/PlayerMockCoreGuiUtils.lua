--!strict
--[=[
	The CoreGui events a mock stands in for. `StarterGui:GetCore(coreName)` answers some names with a
	BindableEvent the CoreGui fires -- the only notice production gets that a friendship changed --
	and only a real client has one, so the mock keeps its own for a test to fire.

	Reached through the `"StarterGui.GetCore"` method domain, so production asks for a core the same
	way against a mock as against the engine (see [CoreGuiUtils.tryToGetCore]).

	@class PlayerMockCoreGuiUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerMockConstants = require("PlayerMockConstants")
local PlayerMockUtils = require("PlayerMockUtils")

local CORE_EVENT_NAMES: { [string]: boolean } = {
	PlayerFriendedEvent = true,
	PlayerUnfriendedEvent = true,
}

local PlayerMockCoreGuiUtils = {}

--[=[
	Returns the mock's stand-in for a CoreGui event, created on first ask so a test and the production
	code observing it meet on the same BindableEvent whichever asks first.

	Use [PlayerMock.callMethod] with `"StarterGui.GetCore"`.

	@param player Player -- must be a PlayerMock
	@param coreName string -- a CoreGui event name, e.g. "PlayerFriendedEvent"
	@return BindableEvent
]=]
function PlayerMockCoreGuiUtils.getCoreEvent(player: Player, coreName: string): BindableEvent
	assert(PlayerMockUtils.isMock(player), "Not a PlayerMock")
	assert(type(coreName) == "string", "Bad coreName")

	if not CORE_EVENT_NAMES[coreName] then
		error(
			string.format(
				"%q is a core the mock models no stand-in for -- bind one with PlayerMock.bindMethod",
				coreName
			),
			3
		)
	end

	local instance = player :: Instance
	local backingName = PlayerMockConstants.CORE_EVENT_NAME_PREFIX .. coreName

	local existing = instance:FindFirstChild(backingName)
	if existing ~= nil then
		return existing :: BindableEvent
	end

	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = backingName
	bindableEvent.Parent = instance
	return bindableEvent
end

return PlayerMockCoreGuiUtils
