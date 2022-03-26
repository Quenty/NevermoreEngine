--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.tie)

-- local serviceBag = require(packages.ServiceBag).new()
-- serviceBag:GetService(packages.TieService)

-- -- Start game
-- serviceBag:Init()
-- serviceBag:Start()

local Door = require(packages.Door)
local Window = require(packages.Window)
local OpenableInterface = require(packages.OpenableInterface)

local door = Instance.new("Folder")
door.Name = "Door"
door.Parent = workspace
Door.new(door)

local window = Instance.new("Folder")
window.Name = "Window"
window.Parent = workspace
Window.new(window)

local doorInterface = OpenableInterface:Get(door)
doorInterface.Opening:Connect(function()
	print("Opening event fired")
end)
doorInterface.IsOpen.Changed:Connect(function()
	print("Door.IsOpen changed", doorInterface.IsOpen.Value)
end)
doorInterface:ObserveIsImplemented():Subscribe(function(isImplemented)
	print("door:ObserveIsImplemented()", isImplemented)
end)


doorInterface:PromiseOpen():Then(function()
	print("Opened")
end)
doorInterface.LastPromise.Value:Then(function()
	print("[doorInterface.LastPromise] Opening finished (last promise value)")
end)

doorInterface:PromiseClose()

print("door:IsImplemented()", doorInterface:IsImplemented())
print("door:IsImplemented()", OpenableInterface:Get(workspace):IsImplemented())

door.Openable.PromiseOpen:Invoke()():Then(function()
	print("Opened promise resolved")
end)
door.Openable.PromiseClose:Invoke()():Then(function()
	print("Closed promise resolved")
end)

