--!strict
--[[
	@class query-data-model.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local Jest = require("Jest")
local QueryDataModelAction = require("query-data-model")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	QueryDataModelAction.register(router)

	local root = Instance.new("Folder")
	root.Name = `QueryDataModelSpec{HttpService:GenerateGUID(false)}`
	root:SetAttribute("Offset", Vector3.new(1, 2, 3))

	local value = Instance.new("IntValue")
	value.Name = "Score"
	value.Value = 42
	value.Parent = root

	local nested = Instance.new("Folder")
	nested.Name = "Nested"
	nested.Parent = value

	root.Parent = workspace

	local controller = {
		root = root,
		rootPath = `Workspace.{root.Name}`,
		query = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "queryDataModel", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}

	return controller
end

describe("queryDataModel", function()
	it("should answer dataModelResult with the instance's common properties", function()
		local controller = setup()

		local response = controller.query({ path = controller.rootPath })

		expect(response.type).toEqual("dataModelResult")
		expect(response.payload.instance).toEqual({
			name = controller.root.Name,
			className = "Folder",
			path = controller.root:GetFullName(),
			properties = { Name = controller.root.Name, ClassName = "Folder" },
			attributes = {},
			childCount = 1,
		})

		controller:Destroy()
	end)

	it("should accept a leading game", function()
		local controller = setup()

		local response = controller.query({ path = `game.{controller.rootPath}` })

		expect(response.payload.instance.name).toEqual(controller.root.Name)

		controller:Destroy()
	end)

	it("should include children down to the requested depth", function()
		local controller = setup()

		local response = controller.query({ path = controller.rootPath, depth = 1 })

		local children = response.payload.instance.children
		expect(#children).toEqual(1)
		expect(children[1].name).toEqual("Score")
		expect(children[1].childCount).toEqual(1)
		expect(children[1].children).toBeNil()

		controller:Destroy()
	end)

	it("should read only the requested properties, skipping Parent and unknown names", function()
		local controller = setup()

		local response = controller.query({
			path = `{controller.rootPath}.Score`,
			properties = { "Value", "Parent", "NotAProperty" },
		})

		expect(response.payload.instance.properties).toEqual({ Value = 42 })

		controller:Destroy()
	end)

	it("should read no properties for an empty list", function()
		local controller = setup()

		local response = controller.query({ path = controller.rootPath, properties = {} })

		expect(response.payload.instance.properties).toEqual({})

		controller:Destroy()
	end)

	it("should serialize attributes when asked", function()
		local controller = setup()

		local response = controller.query({ path = controller.rootPath, includeAttributes = true })

		expect(response.payload.instance.attributes).toEqual({
			Offset = { type = "Vector3", value = { 1, 2, 3 } },
		})

		controller:Destroy()
	end)

	it("should answer INSTANCE_NOT_FOUND for a missing path", function()
		local controller = setup()

		local response = controller.query({ path = `{controller.rootPath}.Missing` })

		expect(response.payload).toEqual({
			success = false,
			code = "INSTANCE_NOT_FOUND",
			message = `Instance not found at path: {controller.rootPath}.Missing`,
		})

		controller:Destroy()
	end)

	it("should send nothing without a path", function()
		local controller = setup()

		expect(controller.query({})).toBeNil()

		controller:Destroy()
	end)
end)
