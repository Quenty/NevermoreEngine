-- Universal Github Installer
-- @author Validark
-- function GitHub:Install(Link, Parent)
--		@returns <Folder/LuaSourceContainer> from Link found starting at Link into Parent

assert(not game:FindFirstChild("NetworkClient"), "You can't install with TeamCreate on. Please turn TeamCreate off to proceed.")

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

local HttpService = game:GetService("HttpService")
local GitHub = {}
local DataSources = {}
local ScriptTypes = {
	[""] = "ModuleScript";
	["local"] = "LocalScript";
	["module"] = "ModuleScript";
	["mod"] = "ModuleScript";
	["loc"] = "LocalScript";
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
	elseif Data:find("HTTP 429") or Data:find("Number of requests exceeded limit") then
		wait(math.random(5))
		warn("Too many requests")
		return GetAsync(...)
	elseif Data:find("Http requests are not enabled") then
		OpenGetRequests = OpenGetRequests + 1
		repeat
			local Success, Data = pcall(HttpService.GetAsync, HttpService, ...)
		until Success and not Data:find("Http requests are not enabled") or not wait(1)
		OpenGetRequests = 0
		return GetAsync(...)
	else
		error(Data, 0)
	end
end

local function GiveSourceToScript(Link, Script)
	DataSources[Script] = Link
	Script.Source = GetAsync(Link)
end

local function InstallRepo(Link, Directory, Parent, Routines, TypesSpecified)
	local Value = #Routines + 1
	Routines[Value] = false
	local Generated, MainExists

	local ScriptCount = 0
	local Scripts = {}

	local FolderCount = 0
	local Folders = {}

	for Link in GetAsync(Link):gmatch("<tr class=\"js%-navigation%-item\">.-<a href=\"(.-)\" class=\"js%-navigation%-open\".-</tr>") do
		if Link:find("/[^/]+/[^/]+/tree") then
			FolderCount = FolderCount + 1
			Folders[FolderCount] = Link
		elseif Link:find("/[^/]+/[^/]+/blob.+%.lua$") then			
			local ScriptName, ScriptClass = Link:match("([%w-_%%]+)%.?(%l*)%.lua$")

			if ScriptName:lower() ~= "install" then
				if ScriptClass == "mod" or ScriptClass == "module" then TypesSpecified = true end

				if ScriptName == "_" or ScriptName:lower() == "main" then
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

		if MainExists then Directory = Directory + 1 end -- :gsub("[^/]+$", "", 1) end			
		local Count = 0

		local function LocateFolder(FolderName)
			Count = Count + 1
			if Count > Directory then
				Directory = Directory + 1
				if (Parent and Parent.Name) ~= FolderName and "Modules" ~= FolderName then
					if FolderName == "App" and Link:find("/Quenty/NevermoreEngine/", 1, true) then FolderName = "ReplicatedStorage" end
					local Success, Service = pcall(game.GetService, game, FolderName)
					if FolderName ~= "Lighting" and Success and Service then
						Parent = Service
					else
						if Generated then
							Parent = Instance.new("Folder", Parent)
							Parent.Name = FolderName
							if not Routines[1] then Routines[1] = Parent end
							DataSources[Parent] = "https://github.com" .. (Sub:match(("/[^/]+"):rep(Directory > 1 and Directory + 2 or Directory)) or warn("[1]", Sub, Directory > 1 and Directory + 2 or Directory) or "")
						else
							local Object = Parent and Parent:FindFirstChild(FolderName)
							if not Object then
								Object = Instance.new("Folder", Parent)
								Object.Name = FolderName
								if not Routines[1] then Routines[1] = Object end
								DataSources[Object] = "https://github.com" .. (Sub:match(("/[^/]+"):rep(Directory > 1 and Directory + 2 or Directory)) or warn("[2]", Sub, Directory > 1 and Directory + 2 or Directory) or "")
								Generated = true
							end
							Parent = Object
						end
					end
				end
			end
		end
		
		Link:gsub("[^/]+/?$", ""):gsub("[^/]+", LocateFolder)

		if MainExists or ScriptCount ~= 1 or ScriptName ~= LastFolder then
			LocateFolder(LastFolder)
		end
		
		local Script = Instance.new(ScriptTypes[ScriptClass or TypesSpecified and "" or "mod"], Parent)
		Script.Name = ScriptName
		if not Routines[1] then Routines[1] = Script end
		coroutine.resume(coroutine.create(GiveSourceToScript), "https://raw.githubusercontent.com" .. ScriptLink:gsub("(/[^/]+/[^/]+/)blob/", "%1", 1), Script)
		
		if MainExists then
			Parent = Script
		end

		for a = 2, ScriptCount do
			local Link = Scripts[a]
			local ScriptName, ScriptClass = Link:match("([%w-_%%]+)%.?(%l*)%.lua$")
			local Script = Instance.new(ScriptTypes[ScriptClass or TypesSpecified and "" or "mod"], Parent)
			Script.Name = ScriptName:gsub("Library$", "", 1):gsub("%%(%x%x)", UrlDecode)
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
	Link = Link:gsub("/$", "")

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
			if Directory and Link:find("blob") then
				ScriptName, ScriptClass = Directory:match("([%w-_%%]+)%.?(%l*)%.lua$")
			end
		else
			Directory = nil
		end
	end

	if not Website then Website = "https://github.com/" end
	Directory = Directory and ("/" .. Directory):gsub("^//", "/") or ""

	-- Threads
	local Routines = RoutineList or {false}
	local Value = #Routines + 1
	Routines[Value] = false

	local Garbage

	if ScriptName then
		local Script = Instance.new(ScriptTypes[ScriptClass or "mod"])
		if not Routines[1] then Routines[1] = Script end
		Script.Name = ScriptName:gsub("Library$", "", 1):gsub("%%(%x%x)", UrlDecode)
		local Link = "https://raw.githubusercontent.com/" .. Organization .. "/" .. Repository .. "/" .. (Tree or "master") .. Directory
		DataSources[Script] = Link
		Script.Source = GetAsync(Link)
		Script.Parent = Parent and not RoutineList and Repository ~= ScriptName and GetFirstChild(Parent, Repository, "Folder") or Parent
	elseif Repository then
		Link = Website .. Organization .. "/" .. Repository .. ((Tree or Directory ~= "") and (Link .. "/tree/" .. (Tree or "master") .. Directory) or "")
		if not Parent then Parent, Garbage = Instance.new("Folder"), true end
		coroutine.resume(coroutine.create(InstallRepo), Link, 1, Parent, Routines) -- "/" .. Repository .. Directory
	elseif Organization then
		local Object = Instance.new("Folder")
		Object.Name = Organization
		Link = Website .. Organization
		if not Routines[1] then Routines[1] = Object end
		
		for Link, Data in GetAsync(Link .. "?tab=repositories"):gmatch('<a href="(/' .. Organization .. '/[^/]+)" itemprop="name codeRepository">(.-)</div>') do
			if not Data:match("Forked from") and not (Organization == "RoStrap" and Link:find("Plugin")) then
				GitHub:Install(Link, Object, Routines)
			end
		end
		Object.Parent = Parent
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

GitHub:Install("/Quenty/NevermoreEngine", game:GetService("ServerScriptService")).Name = "Nevermore"
HttpService.HttpEnabled = ...
