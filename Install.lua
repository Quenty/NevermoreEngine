local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WasHttpEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true

-- @author Quenty
-- Installs the latest version of NevermoreEngine into your game

local function LoadURL(URL)
	URL = URL:gsub("\\", "/"):gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace and swap slashes
	return HttpService:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/master/" .. URL)
end

local function MakeScript(Parent, URL)
	local Name = URL:gmatch("(%w+)%.lua")()
	local New = Parent:FindFirstChild(Name) or Instance.new("ModuleScript", Parent)
	New.Name = Name
	New.Source = LoadURL(URL) or error("Unable to load script")
	return New
end

local function GetDirectory(Parent, URL)
	local DirectoryName = URL:gmatch("%w+\\")()
	if DirectoryName then
		DirectoryName = DirectoryName:sub(1, #DirectoryName-1)

		local New = Parent:FindFirstChild(DirectoryName) or Instance.new("Folder", Parent)
		New.Name = DirectoryName
		return GetDirectory(New, URL:sub(#DirectoryName+2, #URL))
	else
		return Parent
	end
end

print("Loading Nevermore")
MakeScript(ReplicatedStorage, "App/NevermoreEngine.lua")
print("Loading sublibraries")
local MainDirectory = GetDirectory(ServerScriptService, "NevermoreEngine\\")
local Paths = {}
for ScriptPath in (LoadURL("Modules/ModuleList.txt")):gmatch("[^\r\n]+") do
	Paths[#Paths+1] = ScriptPath
end
for Index, ScriptPath in pairs(Paths) do
	MakeScript(GetDirectory(MainDirectory, ScriptPath), "Modules/" .. ScriptPath)
	-- print("Loaded " .. Index .. "/" .. (#Paths) .. " - ", New.Name)
	print(Index, "/", #Paths)
end

HttpService.HttpEnabled = WasHttpEnabled

print("Done loading")