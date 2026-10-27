--!strict
--[[
	@class find-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local FindInstancesAction = require("find-instances")
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
		table.insert(names, found.name)
	end
	table.sort(names)
	return names
end

describe("findInstances", function()
	it("should match names case-insensitively anywhere in the name", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, name = "spawn" })

		expect(response.type).toEqual("findInstancesResult")
		expect(getNames(response)).toEqual({ "BlueSpawn", "RedSpawn", "SpawnName" })
		controller:Destroy()
	end)

	it("should match the whole name with exactName", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, name = "redspawn", exactName = true })

		expect(getNames(response)).toEqual({ "RedSpawn" })
		expect(response.payload.instances[1].path).toEqual(`{controller.root:GetFullName()}.RedSpawn`)
		expect(response.payload.instances[1].className).toEqual("Part")
		controller:Destroy()
	end)

	it("should match a class and its subclasses", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, className = "BasePart" })

		expect(getNames(response)).toEqual({ "BlueSpawn", "RedSpawn" })
		controller:Destroy()
	end)

	it("should match a tag", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, tag = "Spawn" })

		expect(getNames(response)).toEqual({ "RedSpawn" })
		controller:Destroy()
	end)

	it("should stop at the limit and say so", function()
		local controller = setup()

		local response = controller.find({ root = controller.rootPath, name = "spawn", limit = 2 })

		expect(#response.payload.instances).toEqual(2)
		expect(response.payload.truncated).toEqual(true)
		controller:Destroy()
	end)

	it("should fail when the root does not resolve", function()
		local controller = setup()

		local response = controller.find({ root = "Workspace.DoesNotExist" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")
		controller:Destroy()
	end)
end)
