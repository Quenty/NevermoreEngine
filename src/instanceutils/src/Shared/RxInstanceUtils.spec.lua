--!nonstrict
--[[
	@class RxInstanceUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local RxInstanceUtils = require("RxInstanceUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxInstanceUtils.observeChildrenBrio", function()
	local part = Instance.new("Part")
	local observe = RxInstanceUtils.observeChildrenBrio(part)
	local externalResult = nil

	it("should not emit anything", function()
		observe:Subscribe(function(result)
			externalResult = result
		end)

		expect(externalResult).toEqual(nil)
	end)
end)
