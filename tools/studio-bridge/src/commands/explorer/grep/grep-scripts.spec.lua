--!strict
--[[
	@class grep-scripts.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local ActionRouter = require("ActionRouter")
local GrepScriptsAction = require("grep-scripts")
local InstanceQuery = require("InstanceQuery")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local router = ActionRouter.new()
	GrepScriptsAction.register(router)

	local root = Instance.new("Folder")
	root.Name = `GrepScriptsSpec{HttpService:GenerateGUID(false)}`

	-- Setting Source needs plugin security, so the specs supply each script's text
	local sources: { [Instance]: string } = {}
	local function addScript(className: string, name: string, source: string)
		local script = Instance.new(className)
		script.Name = name
		script.Parent = root
		sources[script] = source
	end

	addScript("ModuleScript", "Combat", "local damage = 10\r\nfunction Combat.Hit()\n\treturn DAMAGE * 2\nend")
	addScript("Script", "Main", "print('ready')\nlocal Combat = require(script.Parent.Combat)")

	local readSource = InstanceQuery.readSource
	InstanceQuery.readSource = function(script: Instance): string
		return sources[script] or ""
	end

	root.Parent = workspace

	local controller = {
		root = root,
		rootPath = `Workspace.{root.Name}`,
		grep = function(payload: { [string]: any }): any
			return router:Dispatch({ type = "grepScripts", sessionId = "session-1", payload = payload })
		end,
		Destroy = function(_self)
			InstanceQuery.readSource = readSource
			root:Destroy()
		end,
	}

	return controller
end

local function getLocations(response: any): { string }
	local locations = {}
	for _, match in response.payload.matches do
		local name = string.match(match.path, "[^%.]+$")
		table.insert(locations, `{name}:{match.line}`)
	end
	table.sort(locations)
	return locations
end

describe("grepScripts", function()
	it("should find plain text case-insensitively, with line numbers", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "damage" })

		expect(response.type).toEqual("grepScriptsResult")
		expect(getLocations(response)).toEqual({ "Combat:1", "Combat:3" })
		expect(response.payload.searched).toEqual(2)
		controller:Destroy()
	end)

	it("should keep case with caseSensitive and drop carriage returns", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "damage", caseSensitive = true })

		expect(getLocations(response)).toEqual({ "Combat:1" })
		expect(response.payload.matches[1].text).toEqual("local damage = 10")
		controller:Destroy()
	end)

	it("should treat the pattern plainly unless luaPattern is set", function()
		local controller = setup()

		local plain = controller.grep({ root = controller.rootPath, pattern = "require(" })
		local pattern = controller.grep({ root = controller.rootPath, pattern = "^print%(", luaPattern = true })

		expect(getLocations(plain)).toEqual({ "Main:2" })
		expect(getLocations(pattern)).toEqual({ "Main:1" })
		controller:Destroy()
	end)

	it("should keep a pattern's classes when matching case-insensitively", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "^%S+ DAMAGE", luaPattern = true })

		expect(getLocations(response)).toEqual({ "Combat:1" })
		controller:Destroy()
	end)

	it("should stop listing at the limit, and count past it", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "combat", limit = 1 })

		expect(#response.payload.matches).toEqual(1)
		expect(response.payload.truncated).toEqual(true)
		expect(response.payload.total).toEqual(2)
		expect(response.payload.scripts).toEqual(2)
		controller:Destroy()
	end)

	it("should search only the scripts a query picks out", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "combat", query = "is:Script" })

		expect(getLocations(response)).toEqual({ "Main:2" })
		expect(response.payload.searched).toEqual(1)
		controller:Destroy()
	end)

	it("should search only the scripts a selector picks out", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "combat", selector = "ModuleScript" })

		expect(getLocations(response)).toEqual({ "Combat:2" })
		controller:Destroy()
	end)

	it("should refuse a query that does not parse", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "combat", query = "is:" })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)

	it("should refuse an invalid Lua pattern", function()
		local controller = setup()

		local response = controller.grep({ root = controller.rootPath, pattern = "[", luaPattern = true })

		expect(response.type).toEqual("error")
		expect(response.payload.code).toEqual("INVALID_PAYLOAD")
		controller:Destroy()
	end)
end)
