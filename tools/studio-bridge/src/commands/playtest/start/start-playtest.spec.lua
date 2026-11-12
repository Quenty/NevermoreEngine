--!strict
--[[
	@class start-playtest.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Jest = require("Jest")
local StartPlaytestAction = require("start-playtest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function createModuleFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Pushed"
	return folder
end

local function createPushedModule(name: string, hash: string?): ModuleScript
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = name
	if hash then
		moduleScript:SetAttribute("Hash", hash)
	end
	return moduleScript
end

local function createTemplate(templateModuleFolder: Folder?): Script
	local template = Instance.new("Script")
	local modules = Instance.new("Folder")
	modules.Name = "modules"
	modules.Parent = template
	if templateModuleFolder then
		templateModuleFolder.Parent = modules
	end
	return template
end

local function createRouter(template: Script, moduleFolder: Folder): any
	return {
		GetPlaytestBridgeTemplate = function()
			return template
		end,
		GetModuleFolder = function()
			return moduleFolder
		end,
		Compile = function()
			return function() end
		end,
	}
end

local function plant(router: any): { Instance }
	return StartPlaytestAction._plant(
		router,
		{ precompiled = { "return nil" } },
		`StartPlaytestSpec{HttpService:GenerateGUID(false)}`
	)
end

local function destroyAll(instances: { Instance })
	for _, instance in instances do
		instance:Destroy()
	end
end

describe("StartPlaytestAction._plant", function()
	it("plants only the hashed pushed modules", function()
		local moduleFolder = createModuleFolder()
		createPushedModule("query-logs", "abc").Parent = moduleFolder
		createPushedModule("unhashed").Parent = moduleFolder

		local planted = plant(createRouter(createTemplate(), moduleFolder))
		local entryModules = planted[1]:FindFirstChild("modules") :: Instance
		local plantedModules = entryModules:FindFirstChild("Pushed") :: Instance

		expect(plantedModules:FindFirstChild("query-logs")).never.toBeNil()
		expect(plantedModules:FindFirstChild("unhashed")).toBeNil()

		destroyAll(planted)
	end)

	it("replaces a pushed module folder the template already carries", function()
		local templateModuleFolder = createModuleFolder()
		createPushedModule("stale", "old").Parent = templateModuleFolder
		local moduleFolder = createModuleFolder()
		createPushedModule("query-logs", "abc").Parent = moduleFolder

		local planted = plant(createRouter(createTemplate(templateModuleFolder), moduleFolder))
		local entryModules = planted[1]:FindFirstChild("modules") :: Instance
		local pushedFolders = {}
		for _, child in entryModules:GetChildren() do
			if child.Name == "Pushed" then
				table.insert(pushedFolders, child)
			end
		end

		expect(#pushedFolders).toBe(1)
		expect(pushedFolders[1]:FindFirstChild("query-logs")).never.toBeNil()
		expect(pushedFolders[1]:FindFirstChild("stale")).toBeNil()

		destroyAll(planted)
	end)
end)
