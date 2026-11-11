--!strict
--[[
	@class inspect-instance.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local InspectInstanceAction = require("inspect-instance")
local InstanceQuery = require("InstanceQuery")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	InspectInstanceAction.register(router)

	local root = Instance.new("Folder")
	root.Name = `InspectInstanceSpec{HttpService:GenerateGUID(false)}`
	root:SetAttribute("Offset", Vector3.new(1, 2, 3))

	local value = Instance.new("IntValue")
	value.Name = "Score"
	value.Value = 42
	value.Parent = root

	local nested = Instance.new("Folder")
	nested.Name = "Nested"
	nested.Parent = value

	for _ = 1, 2 do
		local twin = Instance.new("Folder")
		twin.Name = "Twin"
		twin.Parent = root
	end

	local versioned = Instance.new("Folder")
	versioned.Name = "pkg@1.2.3"
	versioned.Parent = root

	local pkg = Instance.new("Folder")
	pkg.Name = "pkg"
	pkg.Parent = versioned

	root.Parent = workspace

	return {
		root = root,
		rootPath = `Workspace.{root.Name}`,
		inspect = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "inspectInstance", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			root:Destroy()
		end,
	}
end

describe("inspectInstance", function()
	it("should answer inspectInstanceResult with the instance, without values unless asked", function()
		local controller = setup()

		local response = controller.inspect({ query = controller.rootPath })

		expect(response.type).toEqual("inspectInstanceResult")
		expect(response.payload.instance).toEqual({
			name = controller.root.Name,
			className = "Folder",
			path = controller.root:GetFullName(),
			properties = {},
			attributes = {},
			childCount = 4,
		})

		controller:Destroy()
	end)

	it("should find the instance by a name alone", function()
		local controller = setup()

		local response = controller.inspect({ query = controller.root.Name })

		expect(response.payload.instance.path).toEqual(controller.root:GetFullName())

		controller:Destroy()
	end)

	it("should prefer the instance whose whole name a one-word query is", function()
		local controller = setup()

		local response = controller.inspect({ query = "Nested", root = controller.rootPath })
		expect(response.payload.instance.name).toEqual("Nested")

		local pkgResponse = controller.inspect({ query = "pkg", root = controller.rootPath })
		expect(pkgResponse.payload.instance.name).toEqual("pkg")

		controller:Destroy()
	end)

	it("should reach a dotted name through a quoted path segment", function()
		local controller = setup()

		local response = controller.inspect({ query = `{controller.root.Name}."pkg@1.2.3".pkg` })

		expect(response.payload.instance.path).toEqual(`{controller.root:GetFullName()}.pkg@1.2.3.pkg`)

		controller:Destroy()
	end)

	it("should include children down to the requested depth", function()
		local controller = setup()

		local response = controller.inspect({ query = `{controller.rootPath}.Score`, depth = 1 })

		local children = response.payload.instance.children
		expect(#children).toEqual(1)
		expect(children[1].name).toEqual("Nested")
		expect(children[1].childCount).toEqual(0)
		expect(children[1].children).toBeNil()

		controller:Destroy()
	end)

	it("should read every readable property, sorted by name, as text and JSON", function()
		local controller = setup()

		local response = controller.inspect({ query = `{controller.rootPath}.Score`, properties = true })

		local byName = {}
		local names = {}
		for _, shown in response.payload.instance.properties do
			byName[shown.name] = shown
			table.insert(names, shown.name)
		end
		expect(byName.Value).toEqual({ name = "Value", text = "42", value = 42 })
		expect(byName.Parent.text).toEqual(controller.root:GetFullName())
		expect(byName.Name.text).toEqual("Score")
		expect(byName.className).toBeNil()

		local sorted = table.clone(names)
		table.sort(sorted, function(a, b)
			return string.lower(a) < string.lower(b)
		end)
		expect(names).toEqual(sorted)

		controller:Destroy()
	end)

	it("should show composite values by component, with colors in 0-255", function()
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 1, 2)
		part.Color = Color3.fromRGB(163, 162, 165)
		part.Material = Enum.Material.Plastic

		local byName = {}
		for _, shown in InspectInstanceAction._readProperties(part) do
			byName[shown.name] = shown
		end
		part:Destroy()

		expect(byName.Size).toEqual({ name = "Size", text = "4, 1, 2", value = { X = 4, Y = 1, Z = 2 } })
		expect(byName.Color.text).toEqual("163, 162, 165")
		expect(byName.Color.value).toEqual({ R = 163, G = 162, B = 165 })
		expect(byName.CFrame.text).toEqual("pos 0, 0, 0  rot 0, 0, 0")
		expect(byName.PivotOffset.text).toEqual("pos 0, 0, 0  rot 0, 0, 0")
		expect(byName.Material.text).toEqual("Plastic")
		expect(byName.size).toBeNil()
	end)

	it("should show attributes when asked", function()
		local controller = setup()

		local response = controller.inspect({ query = controller.rootPath, attributes = true })

		expect(response.payload.instance.attributes).toEqual({
			{ name = "Offset", text = "1, 2, 3", value = { X = 1, Y = 2, Z = 3 } },
		})

		controller:Destroy()
	end)

	it("should fail listing the matches when several instances match", function()
		local controller = setup()

		local response = controller.inspect({ query = "Twin", root = controller.rootPath })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")
		expect(response.payload.message).toContain("2 instances match 'Twin'")
		expect(response.payload.details.total).toEqual(2)
		expect(#response.payload.details.matches).toEqual(2)
		expect(response.payload.details.matches[1].path).toEqual(`{controller.root:GetFullName()}.Twin`)

		controller:Destroy()
	end)

	it("should fail when nothing matches", function()
		local controller = setup()

		local response = controller.inspect({ query = "Missing", root = controller.rootPath })

		expect(response.type).toEqual("error")
		expect(response.payload.message).toEqual(
			`Nothing matches 'Missing' under {controller.rootPath}. Check the spelling, or look for it with 'studio-bridge explorer find'.`
		)

		controller:Destroy()
	end)

	it("should inspect the root without a query, picked out as a query is", function()
		local controller = setup()

		expect(controller.inspect({ root = `{controller.rootPath}."pkg@1.2.3"` }).payload.instance.name).toEqual(
			"pkg@1.2.3"
		)
		expect(controller.inspect({ root = `{controller.root.Name}.Score` }).payload.instance.name).toEqual("Score")

		controller:Destroy()
	end)

	it("should answer the Explorer's services as the top level without a query or root", function()
		local response = InspectInstanceAction._inspect({})
		local game_ = response.instance

		expect(game_.className).toEqual("DataModel")
		expect(game_.childCount).toEqual(#InstanceQuery.getExplorerServices())
		expect(game_.children[1].name).toEqual("Workspace")
		expect(#game_.children).toEqual(game_.childCount)
		expect(game_.children[1].children).toBeNil()

		expect(InspectInstanceAction._inspect({ query = " game " }).instance.className).toEqual("DataModel")
	end)

	it("should inspect the one selected instance", function()
		local controller = setup()
		local selection = {
			Get = function()
				return { controller.root }
			end,
		}

		local response = InspectInstanceAction._inspect({ selection = true }, selection)

		expect(response.instance.name).toEqual(controller.root.Name)

		controller:Destroy()
	end)

	it("should refuse --selection with nothing selected or with a query", function()
		local empty = {
			Get = function()
				return {}
			end,
		}
		local both = {
			Get = function()
				return { workspace, game:GetService("Lighting") }
			end,
		}

		expect(InspectInstanceAction._inspect({ selection = true }, empty).message).toContain(
			"Nothing is selected in Studio"
		)
		expect(InspectInstanceAction._inspect({ selection = true }, both).details.total).toEqual(2)
		expect(InspectInstanceAction._inspect({ selection = true, query = "Part" }, empty).message).toContain(
			"without a query"
		)
	end)

	it("should answer INSTANCE_NOT_FOUND for a missing root", function()
		local controller = setup()

		local response = controller.inspect({ root = `{controller.rootPath}.Missing` })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INSTANCE_NOT_FOUND")

		controller:Destroy()
	end)
end)
