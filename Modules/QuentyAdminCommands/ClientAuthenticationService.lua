local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary


local ClientAuthenticationService = {} do
	local RequestStream = NevermoreEngine.GetDataStreamObject("AuthenticationServiceRequestor")

	local function IsAuthorized(PlayerName)
		-- [PlayerName] Optional playername to check

		return RequestStream:InvokeServer("IsAuthorized", PlayerName)
	end
	ClientAuthenticationService.IsAuthorized = IsAuthorized
	ClientAuthenticationService.isAuthorized = IsAuthorized
end

return ClientAuthenticationService