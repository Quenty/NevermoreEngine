--!strict
--[[
	@class PrecompiledSources.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PrecompiledSources = require("PrecompiledSources")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function plant(folder: Instance, name: string, moduleSource: string)
	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = name
	moduleScript.Source = moduleSource
	moduleScript.Parent = folder
end

describe("PrecompiledSources.createCompiler()", function()
	it("should compile a planted source to its function", function()
		local folder = Instance.new("Folder")
		plant(folder, "1", 'return { fn = function(...) return 1 + 2\nend, source = "return 1 + 2" }')

		local fn = PrecompiledSources.createCompiler(folder)("return 1 + 2")

		expect(fn()).toEqual(3)
	end)

	it("should pass arguments through", function()
		local folder = Instance.new("Folder")
		plant(folder, "1", 'return { fn = function(...) return ...\nend, source = "return ..." }')

		local fn = PrecompiledSources.createCompiler(folder)("return ...")

		expect(fn("a")).toEqual("a")
	end)

	it("should explain that a source that was not planted cannot run", function()
		local fn, err = PrecompiledSources.createCompiler(Instance.new("Folder"))("print(1)")

		expect(fn).toBeNil()
		expect(err).toContain("Load user plugins on playtest")
	end)

	it("should skip a planted module that does not load", function()
		local folder = Instance.new("Folder")
		plant(folder, "broken", "return {")
		plant(folder, "1", 'return { fn = function(...) return 1\nend, source = "return 1" }')

		local fn = PrecompiledSources.createCompiler(folder)("return 1")

		expect(fn()).toEqual(1)
	end)
end)
