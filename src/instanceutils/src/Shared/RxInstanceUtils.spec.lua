--[[
	@class RxInstanceUtils.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local RxInstanceUtils = require("RxInstanceUtils")

return function()
	describe("RxInstanceUtils.observeChildrenBrio", function()
		local part = Instance.new("Part")
		local observe = RxInstanceUtils.observeChildrenBrio(part)
		local externalResult = nil

		it("should not emit anything", function()
			observe:Subscribe(function(result)
				externalResult = result
			end)

			expect(externalResult).to.equal(nil)
		end)
	end)
end
