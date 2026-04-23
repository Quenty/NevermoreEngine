--!nonstrict
--[[
	@class CameraUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local CameraUtils = require("CameraUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("CameraUtils.getCubeoidDiameter", function()
	it("should return 0 for a zero-size vector", function()
		expect(CameraUtils.getCubeoidDiameter(Vector3.zero)).toEqual(0)
	end)

	it("should return the correct diameter for a unit cube", function()
		local diameter = CameraUtils.getCubeoidDiameter(Vector3.one)
		expect(diameter).toBeCloseTo(math.sqrt(3), 5)
	end)

	it("should return the correct diameter for an axis-aligned box", function()
		local diameter = CameraUtils.getCubeoidDiameter(Vector3.new(3, 4, 0))
		expect(diameter).toBeCloseTo(5, 5)
	end)
end)

describe("CameraUtils.fitBoundingBoxToCamera", function()
	it("should return a positive distance for a non-zero bounding box", function()
		local dist = CameraUtils.fitBoundingBoxToCamera(Vector3.one, 70, 16 / 9)
		expect(dist).toBeGreaterThan(0)
	end)

	it("should return a larger distance for a larger bounding box", function()
		local small = CameraUtils.fitBoundingBoxToCamera(Vector3.one, 70, 16 / 9)
		local large = CameraUtils.fitBoundingBoxToCamera(Vector3.one * 10, 70, 16 / 9)
		expect(large).toBeGreaterThan(small)
	end)
end)

describe("CameraUtils.fitSphereToCamera", function()
	it("should return a positive distance", function()
		local dist = CameraUtils.fitSphereToCamera(5, 70, 16 / 9)
		expect(dist).toBeGreaterThan(0)
	end)

	it("should increase distance with a smaller field of view", function()
		local wide = CameraUtils.fitSphereToCamera(5, 90, 1)
		local narrow = CameraUtils.fitSphereToCamera(5, 30, 1)
		expect(narrow).toBeGreaterThan(wide)
	end)

	it("should use horizontal fov when aspect ratio is less than 1", function()
		local landscape = CameraUtils.fitSphereToCamera(5, 70, 2)
		local portrait = CameraUtils.fitSphereToCamera(5, 70, 0.5)
		expect(portrait).toBeGreaterThan(landscape)
	end)
end)
