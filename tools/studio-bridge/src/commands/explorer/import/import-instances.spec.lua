--!strict
--[[
	@class import-instances.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local ImportInstancesAction = require("import-instances")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	ImportInstancesAction.register(router)

	local parent = Instance.new("Folder")
	parent.Name = `ImportInstancesSpec{HttpService:GenerateGUID(false)}`
	parent.Parent = workspace

	local model = Instance.new("IntValue")
	model.Name = "Score"
	model.Value = 42
	local serialized = game:GetService("SerializationService"):SerializeInstancesAsync({ model })
	model:Destroy()

	local controller = {
		parent = parent,
		parentPath = `Workspace.{parent.Name}`,
		data = buffer.tostring(game:GetService("EncodingService"):Base64Encode(serialized)),
		import = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "importInstances", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			parent:Destroy()
		end,
	}

	return controller
end

describe("importInstances", function()
	it("should parent the deserialized instances under the parent path", function()
		local controller = setup()

		local response = controller.import({ data = controller.data, parentPath = controller.parentPath })

		expect(response.type).toEqual("importInstancesResult")
		expect(response.payload.paths).toEqual({ `{controller.parent:GetFullName()}.Score` })
		expect((controller.parent:FindFirstChild("Score") :: IntValue).Value).toEqual(42)

		controller:Destroy()
	end)

	it("should fail when the parent path does not resolve", function()
		local controller = setup()

		local response = controller.import({ data = controller.data, parentPath = "Workspace.DoesNotExist" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")

		controller:Destroy()
	end)

	it("should fail on data that is not a model", function()
		local controller = setup()

		local response = controller.import({
			data = buffer.tostring(game:GetService("EncodingService"):Base64Encode(buffer.fromstring("nope"))),
			parentPath = controller.parentPath,
		})

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("DESERIALIZE_FAILED")

		controller:Destroy()
	end)
end)
