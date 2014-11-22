local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")

local NevermoreEngine       = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary     = NevermoreEngine.LoadLibrary

local qSystems              = LoadCustomLibrary("qSystems")
local MakeMaid              = LoadCustomLibrary("Maid").MakeMaid

local CheckCharacter = qSystems.CheckCharacter
local Make = qSystems.Make


-- NevermoreCommandsLocal
-- @author Quenty
-- Module should load client side in order to enable certain commands in Nevermore. May add support later
-- to handle a GUI interface. 

-- Created August 14th, 2014
-- Last updated August 14th, 2014

assert(script.Name == "NevermoreCommandsLocal")

local NevermoreCommandsLocal = {}
local NevermoreRemoteEvent = NevermoreEngine.GetRemoteEvent("NevermoreCommands")

local LocalPlayer = Players.LocalPlayer

local ClientRequests = {} do-- Requests from the server. 
	local RequestList = {}
	local Maid = MakeMaid()

	local function GetRequest(Name)
		return RequestList[Name:lower()]
	end

	function ClientRequests:AddRequestHandler(RequestName, FunctionExecute)
		assert(RequestList[RequestName:lower()] == nil, "RequestList[" .. RequestName:lower() .. "] is already filled.")

		RequestList[RequestName:lower()] = FunctionExecute
	end

	local function HandleRequest(RequestName, ...)
		-- Errrrr.... this may definitely disconnect if player GUI reset not enabled.
		
		if RequestName and type(RequestName) == "string" then
			local RequestFunction = GetRequest(RequestName)
			if RequestFunction then

				local Args = {...}
				spawn(function()
					RequestFunction(unpack(Args))
				end)
			else
				warn("[NevermoreCommandsLocal] - Request handle for name '" .. RequestName .. "' is unregistered, failed to execute.");
			end
		else
			warn("[NevermoreCommandsLocal] - Invalid RequestName, type not string.")
		end
	end

	local function ConnectEvents()
		Maid.NevermoreRemoteEventOnClientEvent = NevermoreRemoteEvent.OnClientEvent:connect(HandleRequest)
	end
	ClientRequests.ConnectEvents = ConnectEvents
	ClientRequests.connectEvents = ConnectEvents
end


--- LOAD UP LocAL COMMANDS ---

do -- FREECAM
	local LastCharacterCFrame

	ClientRequests:AddRequestHandler("Freecam", function()
		if CheckCharacter(LocalPlayer) then
			LastCharacterCFrame = LocalPlayer.Character.Torso.CFrame
		else
			LastCharacterCFrame = nil
		end

		LocalPlayer.Character = nil
	end)

	ClientRequests:AddRequestHandler("Unfreecam", function()
		workspace.CurrentCamera:Destroy();
		wait(0)
		while not workspace.CurrentCamera do
			wait(0)
		end
		workspace.CurrentCamera.CameraType = "Custom";
		workspace.CurrentCamera.CameraSubject = LocalPlayer.Character;

		if LastCharacterCFrame and CheckCharacter(LocalPlayer) then
			LocalPlayer.Character.Torso.CFrame = LastCharacterCFrame
		end

		LastCharacterCFrame = nil
	end)
end

do -- SONGS
	local LastSong

	local function RemoveLastSong()
		if LastSong then
			local Song = LastSong
			LastSong = nil

			spawn(function()
				while Song.Volume > 0 do
					Song.Volume = Song.Volume - 0.05
					wait()
				end
				Song:Stop()
				Song:Destroy()
			end)
		end
	end

	local function PlaySong(SongId)
		local NewSound = Make("Sound", {
			SoundId    = "rbxassetid://" .. SongId;
			Volume     = 1;
			Archivable = false;
			Parent     = LocalPlayer.PlayerGui;
			Name       = SongId;
			Looped     = true;
			Pitch      = 1;
		})

		NewSound:Play()

		LastSong = NewSound;
	end

	ClientRequests:AddRequestHandler("PlaySong", function(SongId)
		if SongId and tonumber(SongId) then
			RemoveLastSong()
			PlaySong(SongId)
		else
			warn("[NevermoreCommandsLocal] - Could not execute, songId was null")
		end
	end)

	ClientRequests:AddRequestHandler("StopSong", function()
		RemoveLastSong()
	end)
end


--- SETUP COMMAND API ---

function NevermoreCommandsLocal:Initiate()
	--- We need to call this if ResetCoreGuiEnabled is false.

	ClientRequests.ConnectEvents()
end

NevermoreCommandsLocal:Initiate()

return NevermoreCommandsLocal