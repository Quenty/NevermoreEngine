--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.tie)

local Action = require("Action")
local ActionInterface = require("ActionInterface")
local Door = require("Door")
local OpenableInterface = require("OpenableInterface")
local Window = require("Window")

local DO_DOOR_WINDOW_TEST = false

if DO_DOOR_WINDOW_TEST then
	local door = Instance.new("Folder")
	door.Name = "Door"
	door.Parent = workspace
	Door.new(door)

	local window = Instance.new("Folder")
	window.Name = "Window"
	window.Parent = workspace
	Window.new(window)

	local doorInterface = OpenableInterface:Find(door)
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
	print("door:IsImplemented()", OpenableInterface:Find(workspace) ~= nil)

	door.Openable.PromiseOpen:Invoke()():Then(function()
		print("Opened promise resolved")
	end)
	door.Openable.PromiseClose:Invoke()():Then(function()
		print("Closed promise resolved")
	end)
end

local adornee = Instance.new("Folder")
adornee.Name = "Adornee"
adornee.Parent = workspace

do
	-- Implement via OOP
	local smash = Action.new(adornee)
	smash.DisplayName.Value = "Smash"

	smash.Activated:Connect(function()
		print("Smashing")
	end)

	-- Implement via interface calls
	do
		local thrust = ActionInterface.Server:Implement(adornee)
		-- thrust:GetFolder().Name = "Action_Thrust"
		thrust.DisplayName.Value = "Thrust"

		function thrust:Activate()
			thrust.Activated:Fire()
		end

		thrust.Activated:Connect(function()
			print("Thrusting")
		end)
	end

	-- Implement actions via standard Instance.new
	do
		local fling = Instance.new("Folder")
		fling.Name = "Action"
		-- fling.Name = "Action_Fling"

		fling:SetAttribute("DisplayName", "Fling")
		fling:SetAttribute("IsEnabled", false)

		local activated = Instance.new("BindableEvent")
		activated.Name = "Activated"
		activated.Parent = fling

		local activate = Instance.new("BindableFunction")
		activate.Name = "Activate"
		activate.Parent = fling

		activate.OnInvoke = function()
			activated:Fire()
		end

		activated.Event:Connect(function()
			print("Flinging")
		end)

		fling.Parent = adornee
	end
end

for _, action in ActionInterface:GetImplementations(adornee) do
	-- action.Activated:Connect(function()
	-- 	print("Action activation!")
	-- end)
	-- action:Activate()
	action.Activated:Fire()

	action.DisplayName.Changed:Connect(function()
		print(string.format("Display name changed to %q", tostring(action.DisplayName.Value)))
	end)
end

-- local startTime = os.clock()
-- local count = 0
-- ActionInterface:ObserveImplementationsBrio(adornee):Subscribe(function(brio)
-- 	if brio:IsDead() then
-- 		return
-- 	end

-- 	local interface = brio:GetValue()
-- 	local maid = brio:ToMaid()

-- 	count += 1

-- 	maid:GiveTask(interface.DisplayName:Observe():Subscribe(function(name)
-- 			print(string.format("See %d actions (added %q)", count, tostring(name)))
-- 	end))

-- 	brio:ToMaid():GiveTask(function()
-- 		count -= 1
-- 		print(string.format("See %d actions (removed %q)", count, tostring(interface.DisplayName.Value)))
-- 	end)
-- end)

-- print(os.clock() - startTime)

-- local action = adornee.Action
-- action:SetAttribute("DisplayName", Vector3.zero)

-- action.Parent = nil
-- task.wait(0.1)

-- action.Parent = adornee
