-- Installs the latest version of NevermoreEngine into your game
-- @author Quenty
-- @author Narrev

assert(not game:FindFirstChild("NetworkClient"), "You can't install with TeamCreate on. Please turn TeamCreate off to proceed.")

-- Config
local HourGlassSize = 32
local HourGlassCenter = UDim2.new(.5, 0, .5, 0)
local AnimationTime = .5

-- Generation
local HSandPos = UDim2.new(0, .25*HourGlassSize - 1, 0, .25*HourGlassSize - (HourGlassSize <= 64 and 1))
local HSandSize = UDim2.new(0, .5*HourGlassSize + 2, 0, 2 + 38*HourGlassSize / 64)

local GeneratedObjects = {}
local function newInstance(Class, Parent)
	local Object = Instance.new(Class, Parent)
	Object.Name = "NEVERMORE INSTALLER: DO NOT DELETE"
	GeneratedObjects[#GeneratedObjects + 1] = Object
	return Object
end

local function clear()
	for a = 1, #GeneratedObjects do
		local GeneratedObject = GeneratedObjects[a]
		spawn(function()
			if GeneratedObject:IsA("GuiObject") then
				GeneratedObject:TweenPosition(UDim2.new(GeneratedObject.Position.X.Scale, GeneratedObject.Position.X.Offset, -1, -36), "Out", "Quad", 1, false)
			end
			wait(1)
			GeneratedObject:Destroy()
		end)
	end
end
local Screen = newInstance('ScreenGui', game:GetService("StarterGui"))

local Background = newInstance('Frame', Screen)
Background.Size = UDim2.new(1,0,1,36)
Background.Position = UDim2.new(0,0,0,-36)
Background.BackgroundColor3 = Color3.new(1,1,1)
Background.ZIndex = 10

local LoadingText = newInstance('TextLabel', Screen)
LoadingText.FontSize = "Size48";
LoadingText.Position = UDim2.new(.5, 0, .5, HourGlassSize + 24);
LoadingText.Text = "Loading Nevermore";
LoadingText.BackgroundTransparency = 1;
LoadingText.Font = "SourceSansLight"
LoadingText.ZIndex = 10

local ProgressText = newInstance('TextLabel', Screen)
ProgressText.FontSize = "Size32";
ProgressText.Position = UDim2.new(.5, 0, .5, HourGlassSize + 64);
ProgressText.Text = "";
ProgressText.BackgroundTransparency = 1;
ProgressText.Font = "SourceSansLight"
ProgressText.ZIndex = 10

local Empty = newInstance('ImageLabel', Screen)
Empty.Transparency = 1
Empty.Position = HourGlassCenter - UDim2.new(0, .5*HourGlassSize, 0, HourGlassSize)
Empty.Size = UDim2.new(0, HourGlassSize, 0, 2*HourGlassSize)
Empty.ZIndex = 10
Empty.Image = 'rbxassetid://411533268'

local HSand = newInstance('Frame', Empty)
HSand.Transparency = 1
HSand.Position = HSandPos
HSand.Size = HSandSize
HSand.ZIndex = 10
HSand.ClipsDescendants = true

	local HSand2 = newInstance('ImageLabel', HSand)
	HSand2.Transparency = 1
	HSand2.Position = UDim2.new(0, 0, 0, 0)
	HSand2.Size = HSand.Size
	HSand2.ZIndex = 10
	HSand2.Image = 'rbxassetid://411534177'

local LSand = newInstance('Frame', Empty)
LSand.Transparency = 1
LSand.Position = UDim2.new(0, HSandPos.X.Offset, 0, 1.125*HourGlassSize)
LSand.Size = UDim2.new(0, HSandSize.X.Offset, 0, 0)
LSand.ZIndex = 10
LSand.ClipsDescendants = true

	local LSand2 = newInstance('ImageLabel', LSand)
	LSand2.Transparency = 1
	LSand2.Position = UDim2.new(0, 0, 0, 0)
	LSand2.Size = UDim2.new(0, HSandSize.X.Offset, 0, HSandSize.Y.Offset)
	LSand2.ZIndex = 10
	LSand2.Image = 'rbxassetid://411544886'

local done = false
local Stepped = game:GetService("RunService").RenderStepped
spawn(function()
	while not done do
		LSand.Visible = true
		HSand:TweenPosition(HSandPos + UDim2.new(0, 0, 0, HSandSize.Y.Offset), "Out", "Linear", AnimationTime, false)
		HSand2:TweenPosition(UDim2.new(0, 0, 0, -HSandSize.Y.Offset), "Out", "Linear", AnimationTime, false)
		LSand:TweenSize(HSandSize, "Out", "Linear", AnimationTime, false)
		wait(AnimationTime + .03)
		HSand.Visible = false
		local duration = .25	
		local start = tick()
		local dur = 0
		while (dur < duration) do
			local durp = dur / duration
			dur = tick() - start
			Empty.Rotation = -durp * (durp - 2) * 180
			Stepped:wait()
		end
		Empty.Rotation = 180
		HSand.Position = HSandPos
		HSand2.Position = UDim2.new(0, 0, 0, 0)
		LSand.Size = UDim2.new(0, .5*HourGlassSize + 2, 0, 0)
		HSand.Visible = true
		LSand.Visible = false
		Empty.Rotation = 0
	end
	wait(2)
	clear()
end)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WasHttpEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true

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

MakeScript(ReplicatedStorage, "App/NevermoreEngine.lua")

local MainDirectory = GetDirectory(ServerScriptService, "Nevermore\\")
local Paths = {}
for ScriptPath in (LoadURL("Modules/ModuleList.txt")):gmatch("[^\r\n]+") do
	Paths[#Paths+1] = ScriptPath
	print""
end

for Index, ScriptPath in pairs(Paths) do
	MakeScript(GetDirectory(MainDirectory, ScriptPath), "Modules/" .. ScriptPath)
	ProgressText.Text = Index.."/"..#Paths
end

HttpService.HttpEnabled = WasHttpEnabled
ProgressText.Text = "Done!"
done = true
