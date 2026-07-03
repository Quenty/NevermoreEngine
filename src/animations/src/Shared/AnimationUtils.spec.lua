--!nonstrict
--[[
	@class AnimationUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AnimationUtils = require("AnimationUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("AnimationUtils.getAnimationName(animationId)", function()
	it("should format animation name with Animation_ prefix", function()
		local animationId = "12345"
		local result = AnimationUtils.getAnimationName(animationId)
		expect(result).toEqual("Animation_12345")
	end)

	it("should handle numeric animation IDs as strings", function()
		local animationId = "987654"
		local result = AnimationUtils.getAnimationName(animationId)
		expect(result).toEqual("Animation_987654")
	end)

	it("should handle empty string", function()
		local animationId = ""
		local result = AnimationUtils.getAnimationName(animationId)
		expect(result).toEqual("Animation_")
	end)
end)

describe("AnimationUtils.createAnimationFromId(id)", function()
	it("should create an Animation instance", function()
		local animation = AnimationUtils.createAnimationFromId("12345")
		expect(animation).toEqual(expect.any("Instance"))
		expect(animation:IsA("Animation")).toEqual(true)
		animation:Destroy()
	end)

	it("should set correct AnimationId for numeric ID", function()
		local animation = AnimationUtils.createAnimationFromId(12345)
		expect(animation.AnimationId).toEqual("rbxassetid://12345")
		animation:Destroy()
	end)

	it("should set correct AnimationId for string ID", function()
		local animation = AnimationUtils.createAnimationFromId("rbxassetid://12345")
		expect(animation.AnimationId).toEqual("rbxassetid://12345")
		animation:Destroy()
	end)

	it("should set Name with animation name format", function()
		local animation = AnimationUtils.createAnimationFromId(12345)
		expect(animation.Name).toEqual("Animation_rbxassetid://12345")
		animation:Destroy()
	end)

	it("should set Archivable to false", function()
		local animation = AnimationUtils.createAnimationFromId("12345")
		expect(animation.Archivable).toEqual(false)
		animation:Destroy()
	end)
end)
