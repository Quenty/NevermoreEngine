--!nonstrict
--[[
	@class SecretsServiceConstants.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SecretsServiceConstants = require("SecretsServiceConstants")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SecretsServiceConstants", function()
	it("should have REMOTE_FUNCTION_NAME as a string", function()
		expect(type(SecretsServiceConstants.REMOTE_FUNCTION_NAME)).toEqual("string")
	end)

	it("should have REQUEST_SECRET_KEY_NAMES_LIST as a string", function()
		expect(type(SecretsServiceConstants.REQUEST_SECRET_KEY_NAMES_LIST)).toEqual("string")
	end)
end)
