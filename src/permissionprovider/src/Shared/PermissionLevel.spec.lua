--!nonstrict
--[[
	@class PermissionLevel.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PermissionLevel = require("PermissionLevel")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PermissionLevel", function()
	it("should have ADMIN set to admin", function()
		expect(PermissionLevel.ADMIN).toEqual("admin")
	end)

	it("should have CREATOR set to creator", function()
		expect(PermissionLevel.CREATOR).toEqual("creator")
	end)
end)
