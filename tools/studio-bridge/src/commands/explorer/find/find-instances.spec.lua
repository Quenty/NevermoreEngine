--!strict
--[[
	@class find-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local FindInstancesAction = require("find-instances")
local InstanceQuery = require("InstanceQuery")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	FindInstancesAction.register(router)

	local root = Instance.new("Folder")
	root.Name = `FindInstancesSpec{HttpService:GenerateGUID(false)}`

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "RedSpawn"
	spawnPart:AddTag("Spawn")
	spawnPart.Parent = root

	local wedge = Instance.new("WedgePart")
	wedge.Name = "BlueSpawn"
	wedge.Parent = root

	local value = Instance.new("StringValue")
	value.Name = "SpawnName"
	value.Parent = root

	local spawner = Instance.new("ModuleScript")
	spawner.Name = "Spawner"
	spawner.Parent = root

	local other = Instance.new("Script")
	other.Name = "Other"
	other.Parent = root

	root.Parent = workspace

	local controller = {
		root = root,
		rootPath = `Workspace.{root.Name}`,
		find = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "findInstances", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}

	return controller
end

local function getNames(response: any): { string }
	local names = {}
	for _, found in response.payload.instances do
		table.insert(names, found.segments[#found.segments])
	end
	table.sort(names)
	return names
end

describe("findInstances", function()
	it("should match names case-insensitively anywhere in the name", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "spawn" })

		expect(response.type).toEqual("findInstancesResult")
		expect(getNames(response)).toEqual({ "BlueSpawn", "RedSpawn", "SpawnName", "Spawner" })
		controller:Destroy()
	end)

	it("should report each match's path and class", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "redspawn" })

		expect(getNames(response)).toEqual({ "RedSpawn" })
		expect(response.payload.instances[1].path).toEqual(`{controller.root:GetFullName()}.RedSpawn`)
		expect(response.payload.instances[1].className).toEqual("Part")
		expect(response.payload.instances[1].segments).toEqual({ "Workspace", controller.root.Name, "RedSpawn" })
		controller:Destroy()
	end)

	it("should match a class and its subclasses", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "is:BasePart" })

		expect(getNames(response)).toEqual({ "BlueSpawn", "RedSpawn" })
		controller:Destroy()
	end)

	it("should match a tag", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "tag:Spawn" })

		expect(getNames(response)).toEqual({ "RedSpawn" })
		controller:Destroy()
	end)

	it("should pass a selector to QueryDescendants", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, selector = "WedgePart" })

		expect(getNames(response)).toEqual({ "BlueSpawn" })
		controller:Destroy()
	end)

	it("should combine a selector and a query", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, selector = "BasePart", query = "red" })

		expect(getNames(response)).toEqual({ "RedSpawn" })
		controller:Destroy()
	end)

	it("should refuse a selector that does not parse", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, selector = "[[[" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)

	it("should refuse a query that does not parse", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "(spawn" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INVALID_PAYLOAD")
		expect(response.payload.message).toContain("Missing ')'")
		controller:Destroy()
	end)

	it("should keep only scripts whose source contains the grep text", function()
		local controller = setup()
		local readSource = InstanceQuery.readSource
		InstanceQuery.readSource = function(script: Instance): string
			return if script.Name == "Spawner" then "local SPAWN_DELAY = 2" else "print('hi')"
		end

		local response = controller.find({ root = controller.rootPath, grep = "spawn_delay" })
		local pattern = controller.find({ root = controller.rootPath, grep = "^print%(", luaPattern = true })

		InstanceQuery.readSource = readSource
		expect(getNames(response)).toEqual({ "Spawner" })
		expect(getNames(pattern)).toEqual({ "Other" })
		controller:Destroy()
	end)

	it("should stop listing at the limit, and count past it", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, query = "spawn", limit = 2 })

		expect(#response.payload.instances).toEqual(2)
		expect(response.payload.truncated).toEqual(true)
		expect(response.payload.total).toEqual(4)
		expect(response.payload.searched).toEqual(5)
		controller:Destroy()
	end)

	it("should fail when the root does not resolve", function()
		local controller = setup()

		local response = controller.find({ root = "Workspace.DoesNotExist", query = "spawn" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")
		controller:Destroy()
	end)
end)
