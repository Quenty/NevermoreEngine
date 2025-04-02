--[[
	@class ExperienceUtils.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ExperienceUtils = require("ExperienceUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local config = ExperienceUtils.createExperienceConfig({
	factor = 200;
})

describe("ExperienceUtils.getLevel", function()
	it("should return a level", function()
		local level = ExperienceUtils.getLevel(config, 0)
		expect(level).toBe(1)

		level = ExperienceUtils.getLevel(config, 399)
		expect(level).toBe(1)

		level = ExperienceUtils.getLevel(config, 400)
		expect(level).toBe(2)
	end)
end)

describe("ExperienceUtils.experienceFromLevel", function()
	it("should return experience", function()
		local experience = ExperienceUtils.experienceFromLevel(config, 1)
		expect(experience).toBe(0)

		experience = ExperienceUtils.experienceFromLevel(config, 2)
		expect(experience).toBe(400)

		experience = ExperienceUtils.experienceFromLevel(config, 3)
		expect(experience).toBe(1200)
	end)
end)