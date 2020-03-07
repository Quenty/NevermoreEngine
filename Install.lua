-- Universal Github Installer
-- @see Validark
-- function GitHub:Install(Link, Parent)
--		@returns <Folder/LuaSourceContainer> from Link found starting at Link into Parent

-- TODO: This script needs to be refactored
-- luacheck: push ignore

local function GetFirstChild(Parent, Name, Class)
	if Parent then -- GetFirstChildWithNameOfClass
		local Objects = Parent:GetChildren()
		for a = 1, #Objects do
			local Object = Objects[a]
			if Object.Name == Name and Object.ClassName == Class then
				return Object
			end
		end
	end

	local Child = Instance.new(Class)
	Child.Name = Name
	Child.Parent = Parent
	return Child, true
end

-- Services
local HttpService = game:GetService("HttpService")

-- Module
local GitHub = {}

local DataSources = {}

-- Helper Functions
local ScriptTypes = {
	[""] = "ModuleScript";
	["local"] = "LocalScript";
	["module"] = "ModuleScript";
	["mod"] = "ModuleScript";
	["loc"] = "LocalScript";
	["server"] = "Script";
	["client"] = "LocalScript";
}

local function UrlDecode(Character)
	return string.char(tonumber(Character, 16))
end

local OpenGetRequests = 0

local function GetAsync(...)
	repeat until OpenGetRequests == 0 or not wait()
	local Success, Data = pcall(HttpService.GetAsync, HttpService, ...)

	if Success then
		return Data
	elseif Data:find("HTTP 429", 1, true) or Data:find("Number of requests exceeded limit", 1, true) then
		wait(math.random(5))
		warn("Too many requests")
		return GetAsync(...)
	elseif Data:find("Http requests are not enabled", 1, true) then
		OpenGetRequests = OpenGetRequests + 1
		repeat
			local Success, Data = pcall(HttpService.GetAsync, HttpService, ...)
		until Success and not Data:find("Http requests are not enabled", 1, true) or not wait(1)
		OpenGetRequests = 0
		return GetAsync(...)
	elseif Data:find("HTTP 503", 1, true) then
		warn(Data, (...))
		return ""
	elseif Data:find("HttpError: SslConnectFail", 1, true) then
		local t = math.random(2, 5)
		warn("HttpError: SslConnectFail error on " .. tostring((...)) .. " trying again in " .. t .. " seconds.")
		wait(t)
		return GetAsync(...)
	else
		error(Data .. (...), 0)
	end
end

local function GiveSourceToScript(Link, Script)
	DataSources[Script] = Link
	Script.Source = GetAsync(Link)
end

local function InstallRepo(Link, Directory, Parent, Routines, TypesSpecified)
	local Value = #Routines + 1
	Routines[Value] = false
	local MainExists

	local ScriptCount = 0
	local Scripts = {}

	local FolderCount = 0
	local Folders = {}

	local Data = GetAsync(Link)
	local ShouldSkip = false
	local _, StatsGraph = Data:find("d-flex repository-lang-stats-graph", 1, true)

	if StatsGraph then
		ShouldSkip = Data:sub(StatsGraph + 1, (Data:find("</div>", StatsGraph, true) or 0 / 0) - 1):find("%ALua%A") == nil
	end

	if not ShouldSkip then
		for Link in Data:gmatch("<tr class=\"js%-navigation%-item%s*\">.-<a class=\"js%-navigation%-open%s*\" title=\"[^\"]+\" id=\"[^\"]+\"%s*href=\"([^\"]+)\".-</tr>") do
			if Link:find("/[^/]+/[^/]+/tree") then
				FolderCount = FolderCount + 1
				Folders[FolderCount] = Link
			elseif Link:find("/[^/]+/[^/]+/blob.+%.lua$") then
				local ScriptName, ScriptClass = Link:match("([%w-_%%]+)%.?(%l*)%.lua$")

				if ScriptName:lower() ~= "install" and ScriptClass ~= "ignore" and ScriptClass ~= "spec" and ScriptName:lower() ~= "spec" then
					if ScriptClass == "mod" or ScriptClass == "module" then TypesSpecified = true end

					if ScriptName == "_" or ScriptName:lower() == "main" or ScriptName:lower() == "init" then
						ScriptCount = ScriptCount + 1
						for a = ScriptCount, 2, -1 do
							Scripts[a] = Scripts[a - 1]
						end
						Scripts[1] = Link
						MainExists = true
					else
						ScriptCount = ScriptCount + 1
						Scripts[ScriptCount] = Link
					end
				end
			end
		end
	end

	if ScriptCount > 0 then
		local ScriptLink = Scripts[1]
		local ScriptName, ScriptClass = ScriptLink:match("([%w-_%%]+)%.?(%l*)%.lua$")
		ScriptName = ScriptName:gsub("Library$", "", 1):gsub("%%(%x%x)", UrlDecode)
		local Sub = Link:sub(19)
		local Link = Sub:gsub("^(/[^/]+/[^/]+)/tree/[^/]+", "%1", 1)
		local LastFolder = Link:match("[^/]+$")
		LastFolder = LastFolder:match("^RBX%-(.-)%-Library$") or LastFolder

		if MainExists then
			local Directory = LastFolder:gsub("%%(%x%x)", UrlDecode)
			ScriptName, ScriptClass = Directory:match("([%w-_%%]+)%.?(%l*)%.lua$")
			if not ScriptName then ScriptName = Directory:match("^RBX%-(.-)%-Library$") or Directory end
			if ScriptClass == "mod" or ScriptClass == "module" then TypesSpecified = true end
		end

		-- if MainExists or ScriptCount ~= 1 or ScriptName ~= (LastFolder:match("^RBX%-(.-)%-Library$") or LastFolder) then
		if MainExists then Directory = Directory + 2 end -- :gsub("[^/]+$", "", 1) end
		local Count = 0

		local function LocateFolder(FolderName)
			Count = Count + 1
			if Count > Directory then
				Directory = Directory + 1
				if (Parent and Parent.Name) ~= FolderName and "Modules" ~= FolderName then
					-- local Success, Service = pcall(game.GetService, game, FolderName)
					-- if FolderName ~= "Lighting" and Success and Service then
					-- 	Parent = Service
					-- else
					local Generated
					Parent, Generated = GetFirstChild(Parent, FolderName, "Folder")
					if Generated then
						if not Routines[1] then Routines[1] = Parent end
						DataSources[Parent] = "https://github.com" .. (Sub:match(("/[^/]+"):rep(Directory > 2 and Directory + 2 or Directory)) or warn("[1]", Sub, Directory > 1 and Directory + 2 or Directory) or "")
					end
					-- end
				end
			end
		end

		Link:gsub("[^/]+$", ""):gsub("[^/]+", LocateFolder)

		if MainExists or ScriptCount ~= 1 or ScriptName ~= LastFolder then
			LocateFolder(LastFolder)
		end

		local Script = GetFirstChild(Parent, ScriptName, ScriptTypes[ScriptClass or TypesSpecified and "" or "mod"] or "ModuleScript")
		if not Routines[1] then Routines[1] = Script end
		coroutine.resume(coroutine.create(GiveSourceToScript), "https://raw.githubusercontent.com" .. ScriptLink:gsub("(/[^/]+/[^/]+/)blob/", "%1", 1), Script)

		if MainExists then
			Parent = Script
		end

		for a = 2, ScriptCount do
			local Link = Scripts[a]
			local ScriptName, ScriptClass = Link:match("([%w-_%%]+)%.?(%l*)%.lua$")
			local Script = GetFirstChild(Parent, ScriptName:gsub("Library$", "", 1):gsub("%%(%x%x)", UrlDecode), ScriptTypes[ScriptClass or TypesSpecified and "" or "mod"] or "ModuleScript")
			coroutine.resume(coroutine.create(GiveSourceToScript), "https://raw.githubusercontent.com" .. Link:gsub("(/[^/]+/[^/]+/)blob/", "%1", 1), Script)
		end
	end

	for a = 1, FolderCount do
		local Link = Folders[a]
		coroutine.resume(coroutine.create(InstallRepo), "https://github.com" .. Link, Directory, Parent, Routines, TypesSpecified)
	end

	Routines[Value] = true
end

function GitHub:Install(Link, Parent, RoutineList)
	-- Installs Link into Parent

	if Link:byte(-1) == 47 then --gsub("/$", "")
		Link = Link:sub(1, -2)
	end

	-- Extract Link Data
	local Organization, Repository, Tree, ScriptName, ScriptClass
	local Website, Directory = Link:match("^(https://[raw%.]*github[usercontent]*%.com/)(.+)")
	Organization, Directory = (Directory or Link):match("^/?([%w-_%.]+)/?(.*)")
	Repository, Directory = Directory:match("^([%w-_%.]+)/?(.*)")

	if Website == "https://raw.githubusercontent.com/" then
		if Directory then
			Tree, Directory = Directory:match("^([^/]+)/(.+)")
			if Directory then
				ScriptName, ScriptClass = Directory:match("([%w-_%%]+)%.?(%l*)%.lua$")
			end
		end
	elseif Directory then
		local a, b = Directory:find("^[tb][rl][eo][eb]/[^/]+")
		if a and b then
			Tree, Directory = Directory:sub(6, b), Directory:sub(b + 1)
			if Directory == "" then Directory = nil end
			if Directory and Link:find("blob", 1, true) then
				ScriptName, ScriptClass = Directory:match("([%w-_%%]+)%.?(%l*)%.lua$")
			end
		else
			Directory = nil
		end
	end

	if ScriptName and (ScriptName == "_" or ScriptName:lower() == "main" or ScriptName:lower() == "init") then
		return GitHub:Install("https://github.com/" .. Organization .. "/" .. Repository .. "/tree/" .. (Tree or "master") .. "/" .. Directory:gsub("/[^/]+$", ""):gsub("^/", ""), Parent, RoutineList)
	end

	if not Website then Website = "https://github.com/" end
	Directory = Directory and ("/" .. Directory):gsub("^//", "/") or ""

	-- Threads
	local Routines = RoutineList or {false}
	local Value = #Routines + 1
	Routines[Value] = false

	local Garbage

	if ScriptName then
		Link = "https://raw.githubusercontent.com/" .. Organization .. "/" .. Repository .. "/" .. (Tree or "master") .. Directory
		local Source = GetAsync(Link)
		local Script = GetFirstChild(Parent and not RoutineList and Repository ~= ScriptName and Parent.Name ~= ScriptName and Parent.Name ~= Repository and GetFirstChild(Parent, Repository, "Folder") or Parent, ScriptName:gsub("Library$", "", 1):gsub("%%(%x%x)", UrlDecode), ScriptTypes[ScriptClass or "mod"] or "ModuleScript")
		DataSources[Script] = Link
		if not Routines[1] then Routines[1] = Script end
		Script.Source = Source
	elseif Repository then
		Link = Website .. Organization .. "/" .. Repository .. ((Tree or Directory ~= "") and ("/tree/" .. (Tree or "master") .. Directory) or "")
		if not Parent then Parent, Garbage = Instance.new("Folder"), true end
		coroutine.resume(coroutine.create(InstallRepo), Link, 1, Parent, Routines) -- "/" .. Repository .. Directory
	elseif Organization then
		Link = Website .. Organization
		local Data = GetAsync(Link .. "?tab=repositories")
		local Object = GetFirstChild(Parent, Organization, "Folder")

		if not Routines[1] then Routines[1] = Object end

		for Link, Data in Data:gmatch('href="(/' .. Organization .. '/[^/]+)" itemprop="name codeRepository"(.-)</div>') do
			--if not Data:find("Forked from", 1, true) and not Link:find("Plugin", 1, true) and not Link:find(".github.io", 1, true) then
				GitHub:Install(Link, Object, Routines)
			--end
		end
	end

	Routines[Value] = true

	if not RoutineList then
		repeat
			local Done = 0
			local Count = #Routines
			for a = 1, Count do
				if Routines[a] then
					Done = Done + 1
				end
			end
		until Done == Count or not wait()
		local Object = Routines[1]
		if Garbage then
			Object.Parent = nil
			Parent:Destroy()
		end
		DataSources[Object] = Link
		return Object
	end
end

-- luacheck: pop ignore
print("Installing NevermoreEngine...")

local threadsCompleted = table.create(2, false)

spawn(function()
	GitHub:Install(
		"https://github.com/Quenty/NevermoreEngine/tree/version2/Modules",
		game:GetService("ServerScriptService")
	)
	threadsCompleted[1] = true
end)

spawn(function()
	local init = GitHub:Install("https://github.com/Quenty/NevermoreEngine/blob/version2/loader/ReplicatedStorage/Nevermore/init.lua")
	init.Nevermore.Nevermore.Parent = game:GetService("ReplicatedStorage")
	init:Destroy()
	threadsCompleted[2] = true
end)

repeat
	wait()
	local finished = true
	for _, thread in pairs(threadsCompleted) do
		if not thread then
			finished = false
		end
	end
until finished

HttpService.HttpEnabled = ...

print("NevermoreEngine installed.")
