-- ClientAuthenticationService.lua
-- @author Quenty

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local RemoteManager     = LoadCustomLibrary("RemoteManager")
local Signal            = LoadCustomLibrary("Signal")

local ClientAuthenticationService = {} do
	local RequestStream = RemoteManager:GetFunction("AuthenticationServiceRequestor")
	local EventStream   = RemoteManager:GetEvent("AuthenticationServiceEventStream")

	ClientAuthenticationService.AuthenticationChanged = Signal()

	EventStream:Listen(function(AuthenticationChange)
		if type(AuthenticationChange) == "string" then
			AuthenticationChange = AuthenticationChange:lower()

			if AuthenticationChange == "authorized" then
				ClientAuthenticationService.AuthenticationChanged:fire(true)
			elseif AuthenticationChange == "deauthorized" then
				ClientAuthenticationService.AuthenticationChanged:fire(false)
			else -- Oh noes!
				warn("[ClientAuthenticationService] - Unable to process AuthenticationChange event, AuthenticationChange value = '" .. tostring(AuthenticationChange) .. "'")
			end
		else
			warn("[ClientAuthenticationService] - Unable to process AuthenticationChange event, AuthenticationChange value is not a string. It is a '" .. type(AuthenticationChange) .. "' value.")
		end
	end)

	local function IsAuthorized(PlayerName)
		-- [PlayerName] Optional playername to check

		return RequestStream:CallServer("IsAuthorized", PlayerName)
	end
	ClientAuthenticationService.IsAuthorized = IsAuthorized
	ClientAuthenticationService.isAuthorized = IsAuthorized
end

return ClientAuthenticationService
