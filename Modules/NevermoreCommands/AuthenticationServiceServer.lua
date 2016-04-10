-- AuthenticationServiceServer.lua
-- @author Quenty
-- This script handles authenticating players who, well, I want authenticated, and defining permissions

local AuthenticationService = {} do
	local Players           = game:GetService("Players")
	
	local LoadCustomLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))
	local RemoteManger      = LoadCustomLibrary("RemoteManger")
	local CompareStrings    = LoadCustomLibrary("qString").CompareStrings
	local GetPlayerFromName = LoadCustomLibrary("qPlayer").GetPlayerFromName

	local Authorized        = LoadCustomLibrary("QACSettings").Authorized

	local RequestStream     = RemoteManger:GetFunction("AuthenticationServiceRequestor")
	local EventStream       = RemoteManger:GetEvent("AuthenticationServiceEventStream")

	local function IsAuthorized(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		for _, AuthenticationString in pairs(Authorized) do
			if CompareStrings(tostring(AuthenticationString), PlayerName) then
				return true
			end
		end
		return false
	end
	AuthenticationService.IsAuthorized = IsAuthorized
	AuthenticationService.isAuthorized = IsAuthorized

	local function Authorize(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		if not IsAuthorized(PlayerName) then
			-- Authorized[PlayerName] = true
			Authorized[#Authorized+1] = PlayerName

			local Player = GetPlayerFromName(PlayerName)
			if Player then
				EventStream:SendToPlayer(Player, "Authorized")
			end
		end
	end
	AuthenticationService.Authorize = Authorize
	AuthenticationService.authorize = Authorize

	local function Deauthorize(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		for Index, AuthenticationString in pairs(Authorized) do
			if CompareStrings(tostring(AuthenticationString), PlayerName) then
				table.remove(Authorized, Index)

				local Player = GetPlayerFromName(PlayerName)

				if Player then
					EventStream:SendToPlayer(Player, "Deauthorized")
				else
					print("[AuthenticationService] [Deauthorize] - Could not find deauthorized player '" .. PlayerName .. "', did not send deauthorization event.")
				end

				break
			end
		end
	end
	AuthenticationService.Deauthorize = Deauthorize
	AuthenticationService.deauthorize = Deauthorize

	RequestStream:Callback(function(Player, Request, Data)
		Player = Player or Players.LocalPlayer

		if Request == "IsAuthorized" then
			return AuthenticationService.IsAuthorized(Data or Player)
		else
			error("[AuthenticationService] - Unknown request")
		end
	end)
end

return AuthenticationService
