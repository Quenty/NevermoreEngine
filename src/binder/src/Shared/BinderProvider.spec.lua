--[[
	@class BinderProvider.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return function()
	describe("BinderProvider.new()", function()
		local provider
		local initialized = false

		it("should execute immediately", function()
			provider = BinderProvider.new("BinderServiceName", function(self, arg)
				initialized = true
				assert(arg == 12345, "Bad arg")

				self:Add(Binder.new("Test", function()
					return { Destroy = function() end; }
				end))
			end)

			expect(provider).to.be.a("table")
		end)

		it("should initialize", function()
			expect(initialized).to.equal(false)
			provider:Init(12345)
			expect(initialized).to.equal(true)
		end)

		it("should contain the binder", function()
			expect(provider.Test).to.be.a("table")
		end)

		provider:Destroy()
	end)

end
