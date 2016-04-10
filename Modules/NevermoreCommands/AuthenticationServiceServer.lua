-- AuthenticationServiceServer.lua
-- @author Quenty
-- This script handles authenticating players who, well, I want authenticated, and defining permissions

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local qString           = LoadCustomLibrary("qString")
local qPlayer           = LoadCustomLibrary("qPlayer")
local QACSettings       = LoadCustomLibrary("QACSettings")
local RemoteManger      = LoadCustomLibrary("RemoteManger")

local AuthenticationService = {} do
	local Authorized = QACSettings.Authorized 

	local RequestStream = RemoteManger:GetFunction("AuthenticationServiceRequestor")
	local EventStream   = RemoteManger:GetEvent("AuthenticationServiceEventStream")

	local function IsAuthorized(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		for _, AuthenticationString in pairs(Authorized) do
			if qString.CompareStrings(tostring(AuthenticationString), PlayerName) then
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

			local Player = qPlayer.GetPlayerFromName(PlayerName)
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
			if qString.CompareStrings(tostring(AuthenticationString), PlayerName) then
				table.remove(Authorized, Index)

				local Player = qPlayer.GetPlayerFromName(PlayerName)

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
