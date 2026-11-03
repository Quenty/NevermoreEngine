--!strict
--[[
	@class export-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local ExportInstancesAction = require("export-instances")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	ExportInstancesAction.register(router)

	local root = Instance.new("Folder")
	root.Name = `ExportInstancesSpec{HttpService:GenerateGUID(false)}`

	local value = Instance.new("IntValue")
	value.Name = "Score"
	value.Value = 42
	value.Parent = root

	root.Parent = workspace

	local controller = {
		root = root,
		rootPath = `Workspace.{root.Name}`,
		export = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "exportInstances", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}

	return controller
end

describe("exportInstances", function()
	it("should answer with a binary model that deserializes to the same instances", function()
		local controller = setup()

		local response = controller.export({ paths = { controller.rootPath } })

		expect(response.type).toEqual("exportInstancesResult")
		expect(response.payload.paths).toEqual({ controller.root:GetFullName() })

		local decoded = game:GetService("EncodingService"):Base64Decode(buffer.fromstring(response.payload.data))
		expect(buffer.readstring(decoded, 0, 8)).toEqual("<roblox!")

		local instances = game:GetService("SerializationService"):DeserializeInstancesAsync(decoded)
		expect(#instances).toEqual(1)
		expect(instances[1].Name).toEqual(controller.root.Name)
		expect((instances[1]:FindFirstChild("Score") :: IntValue).Value).toEqual(42)

		controller:Destroy()
	end)

	it("should fail when a path does not resolve", function()
		local controller = setup()

		local response = controller.export({ paths = { controller.rootPath, "Workspace.DoesNotExist" } })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")

		controller:Destroy()
	end)

	it("should fail without paths", function()
		local controller = setup()

		local response = controller.export({ paths = {} })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INVALID_PAYLOAD")

		controller:Destroy()
	end)
end)
