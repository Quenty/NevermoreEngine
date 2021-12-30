--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly
	@server
	@class ResetService
]=]

local require = require(script.Parent.loader).load(script)

local GetRemoteEvent = require("GetRemoteEvent")
local ResetServiceConstants = require("ResetServiceConstants")

local ResetService = {}

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].
]=]
function ResetService:Init()
	assert(not self._remoteEvent, "Already initialized")

	self._remoteEvent = GetRemoteEvent(ResetServiceConstants.REMOTE_EVENT_NAME)
	self._remoteEvent.OnServerEvent:Connect(function(player)
		self:_resetCharacter(player)
	end)
end

function ResetService:_resetCharacter(player)
	player:LoadCharacter()
end

return ResetService