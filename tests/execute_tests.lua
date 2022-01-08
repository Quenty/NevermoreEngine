--[=[
	Executes tests
	@class execute_tests
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NevermoreLoader = require(ReplicatedStorage:WaitForChild("Nevermore"))

local function testModule(module)
	-- Load directly
	require(module)

	-- Test that we can actually load the module via Nevermore
	NevermoreLoader(module.Name)
end

local function testFolder(folder)
	for _, item in pairs(folder:GetDescendants()) do
		if item:IsA("ModuleScript")
			and not item:FindFirstAncestorWhichIsA("ModuleScript") then

			if not item.Name:find(".story") then
				testModule(item)
			end
		end
	end
end

-- Test
testFolder(ServerScriptService.Nevermore)