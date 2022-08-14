--[=[
	Handles reset requests since Roblox's reset system doesn't handle ragdolls correctly
	@server
	@class ResetService
]=]

local require = require(script.Parent.loader).load(script)

local GetRemoteEvent = require("GetRemoteEvent")
local ResetServiceConstants = require("ResetServiceConstants")
local Maid = require("Maid")

local ResetService = {}
ResetService.ServiceName = "ResetService"

--[=[
	Initializes the reset service. Should be done via a [ServiceBag].
]=]
function ResetService:Init()
	assert(not self._remoteEvent, "Already initialized")

	self._maid = Maid.new()

	self._remoteEvent = GetRemoteEvent(ResetServiceConstants.REMOTE_EVENT_NAME)
	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(player)
		self:_resetCharacterYielding(player)
	end))
end

function ResetService:_resetCharacterYielding(player)
	player:LoadCharacter()
end

function ResetService:Destroy()
	self._maid:DoCleaning()
end

return ResetService