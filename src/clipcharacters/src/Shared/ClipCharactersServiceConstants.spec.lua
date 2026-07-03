--!nonstrict
--[[
	@class ClipCharactersServiceConstants.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ClipCharactersServiceConstants = require("ClipCharactersServiceConstants")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("ClipCharactersServiceConstants", function()
	it("should have COLLISION_GROUP_NAME set to ClipCharacters", function()
		expect(ClipCharactersServiceConstants.COLLISION_GROUP_NAME).toEqual("ClipCharacters")
	end)
end)
