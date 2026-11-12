--!strict
--[[
	@class InstanceRef.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local InstanceRef = require("InstanceRef")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InstanceRef.from", function()
	it("should name the path from the service down, without the DataModel", function()
		local folder = Instance.new("Folder")
		folder.Name = `InstanceRefSpec{HttpService:GenerateGUID(false)}`
		local part = Instance.new("Part")
		part.Name = "Door"
		part.Parent = folder
		folder.Parent = workspace

		local ref = InstanceRef.from(part)

		expect(ref).toEqual({
			path = part:GetFullName(),
			segments = { "Workspace", folder.Name, "Door" },
			className = "Part",
		})
		folder:Destroy()
	end)

	it("should keep a name with dots as one segment", function()
		local folder = Instance.new("Folder")
		folder.Name = "jsdotlua_shared@17.2.1"
		local value = Instance.new("StringValue")
		value.Name = "Value"
		value.Parent = folder

		local ref = InstanceRef.from(value)

		expect(ref.path).toEqual("jsdotlua_shared@17.2.1.Value")
		expect(ref.segments).toEqual({ "jsdotlua_shared@17.2.1", "Value" })
		folder:Destroy()
	end)

	it("should name the DataModel itself", function()
		expect(InstanceRef.from(game).segments).toEqual({ game.Name })
	end)
end)

describe("InstanceRef.fromList", function()
	it("should keep the order", function()
		local refs = InstanceRef.fromList({ workspace, game:GetService("Lighting") })

		expect(refs[1].path).toEqual("Workspace")
		expect(refs[2].path).toEqual("Lighting")
	end)
end)
