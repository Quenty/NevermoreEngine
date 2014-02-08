local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qString           = LoadCustomLibrary("qString")

qSystems:Import(getfenv(0))

-- This script handles authenticating players who, well, I want authenticated, and defining permissions
-- AuthenticationService.lua
-- @author Quenty
-- Last Modified February 6th, 2014

local AuthenticationService = {} do
	local Authorized = {
		-- Testing purposes
		"Player1";
		"Player";
		
		-- Regular
		"Quenty";
		"Mauv";
		-- "ColorfulBody";
		"Merely";
		"Seranok";
		"blobbyblob";
		"xXxMoNkEyMaNxXx";

		-- Chill admins 
		"Anaminus";
		"sim0nsays";
		"tone";
	}

	local function IsAuthorized(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		for _, AuthenticationString in pairs(Authorized) do
			if qString.CompareStrings(tostring(AuthenticationString), PlayerName) then
				return true
			elseif qString.CompareStrings("Quenty", PlayerName) then
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
			Authorized[PlayerName] = true
		end
	end
	AuthenticationService.Authorize = Authorize
	AuthenticationService.authorize = Authorize

	local function Deauthorize(PlayerName)
		PlayerName = tostring(PlayerName) -- Incase they send in a player

		for Index, AuthenticationString in pairs(Authorized) do
			if qString.CompareStrings(tostring(AuthenticationString), PlayerName) then
				table.remove(Authorized, Index)
				break
			end
		end
	end
	AuthenticationService.Deauthorize = Deauthorize
	AuthenticationService.deauthorize = Deauthorize
end

return AuthenticationService