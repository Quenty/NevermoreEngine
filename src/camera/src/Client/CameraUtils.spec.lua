--!strict
--[[
	@class CameraUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

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

local FULL_RECT = Rect.new(0, 0, 1, 1)

describe("CameraUtils.fitSphereToCameraRect", function()
	it("should match fitSphereToCamera for the full viewport in landscape", function()
		local expected = CameraUtils.fitSphereToCamera(5, 35, 16 / 9)
		local offset = CameraUtils.fitSphereToCameraRect(5, 35, 16 / 9, FULL_RECT)
		expect(offset.X).toBeCloseTo(0, 5)
		expect(offset.Y).toBeCloseTo(0, 5)
		expect(offset.Z).toBeCloseTo(expected, 5)
	end)

	it("should match fitSphereToCamera for the full viewport in portrait", function()
		local expected = CameraUtils.fitSphereToCamera(5, 35, 0.5)
		local offset = CameraUtils.fitSphereToCameraRect(5, 35, 0.5, FULL_RECT)
		expect(offset.X).toBeCloseTo(0, 5)
		expect(offset.Y).toBeCloseTo(0, 5)
		expect(offset.Z).toBeCloseTo(expected, 5)
	end)

	it("should increase distance for a smaller rect", function()
		local full = CameraUtils.fitSphereToCameraRect(5, 35, 16 / 9, FULL_RECT)
		local partial = CameraUtils.fitSphereToCameraRect(5, 35, 16 / 9, Rect.new(0, 0, 1, 0.7))
		expect(partial.Z).toBeGreaterThan(full.Z)
	end)
end)

describe("CameraUtils.fitBoundingBoxToCameraRect", function()
	it("should match fitBoundingBoxToCamera for the full viewport", function()
		local size = Vector3.new(4, 6, 2)
		local expected = CameraUtils.fitBoundingBoxToCamera(size, 35, 16 / 9)
		local offset = CameraUtils.fitBoundingBoxToCameraRect(size, 35, 16 / 9, FULL_RECT)
		expect(offset.X).toBeCloseTo(0, 5)
		expect(offset.Y).toBeCloseTo(0, 5)
		expect(offset.Z).toBeCloseTo(expected, 5)
	end)

	it("should match fitSphereToCameraRect with the bounding sphere", function()
		local size = Vector3.new(4, 6, 2)
		local rect = Rect.new(0, 0, 1, 0.7)
		local radius = CameraUtils.getCubeoidDiameter(size) / 2
		local expected = CameraUtils.fitSphereToCameraRect(radius, 35, 16 / 9, rect)
		local offset = CameraUtils.fitBoundingBoxToCameraRect(size, 35, 16 / 9, rect)
		expect((offset - expected).Magnitude).toBeCloseTo(0, 5)
	end)
end)

describe("CameraUtils.fitBoundingBoxToCameraRectExact", function()
	it("should fit a face-on cube so its front face fills the viewport height", function()
		local size, fovDeg = 4, 35
		local offset = CameraUtils.fitBoundingBoxToCameraRectExact(
			CFrame.new(),
			Vector3.one * size,
			CFrame.new(),
			fovDeg,
			16 / 9,
			FULL_RECT
		)

		-- The front face sits size / 2 closer than the center, and its half height fills tan(fov / 2)
		expect(offset.X).toBeCloseTo(0, 5)
		expect(offset.Y).toBeCloseTo(0, 5)
		expect(offset.Z).toBeCloseTo(size / 2 + size / (2 * math.tan(math.rad(fovDeg) / 2)), 5)
	end)

	it("should fit a wide box closer than its bounding sphere", function()
		local size = Vector3.new(10, 2, 2)
		local exact =
			CameraUtils.fitBoundingBoxToCameraRectExact(CFrame.new(), size, CFrame.new(), 35, 16 / 9, FULL_RECT)
		local sphere = CameraUtils.fitBoundingBoxToCameraRect(size, 35, 16 / 9, FULL_RECT)
		expect(exact.Z).toBeLessThan(sphere.Z)
	end)

	it("should move the camera down when the bottom of the screen is covered", function()
		local offset = CameraUtils.fitBoundingBoxToCameraRectExact(
			CFrame.new(),
			Vector3.new(4, 6, 2),
			CFrame.Angles(math.rad(-20), math.rad(30), 0),
			35,
			16 / 9,
			Rect.new(0, 0, 1, 0.7)
		)
		expect(offset.Y).toBeLessThan(0)
	end)
end)

describe("CameraUtils.boundingBoxPoints", function()
	it("should return the 8 corners of the box", function()
		local points = CameraUtils.boundingBoxPoints(CFrame.new(10, 0, 0), Vector3.new(2, 4, 6))
		expect(#points).toEqual(8)

		local min, max = points[1], points[1]
		for _, point in points do
			min = min:Min(point)
			max = max:Max(point)
		end
		expect((min - Vector3.new(9, -2, -3)).Magnitude).toBeCloseTo(0, 5)
		expect((max - Vector3.new(11, 2, 3)).Magnitude).toBeCloseTo(0, 5)
	end)
end)

describe("CameraUtils.getPointsCameraSubRectShift", function()
	it("should match fitPointsToCameraRect at its depth", function()
		local rotation = CFrame.Angles(math.rad(-30), math.rad(35), 0)
		local points = CameraUtils.boundingBoxPoints(CFrame.Angles(0, math.rad(20), 0), Vector3.new(8, 3, 2))
		for index, point in points do
			points[index] = rotation:VectorToObjectSpace(point)
		end

		local rect = Rect.new(0.1, 0.1, 0.6, 0.65)
		local fit = CameraUtils.fitPointsToCameraRect(points, 70, 16 / 9, rect)
		local shift = CameraUtils.getPointsCameraSubRectShift(points, fit.Z, 70, 16 / 9, rect)

		expect(shift.X).toBeCloseTo(fit.X, 5)
		expect(shift.Y).toBeCloseTo(fit.Y, 5)
		expect(shift.Z).toEqual(0)
	end)
end)

describe("CameraUtils.getCameraSubRectShift", function()
	local function projectToNdc(offset: Vector3, depth: number, fovDeg: number, aspectRatio: number): Vector2
		-- Subject sits on the original look axis; the camera has moved by offset
		local relative = Vector3.new(0, 0, -depth) - offset
		local tanHalfFov = math.tan(math.rad(fovDeg) / 2)
		return Vector2.new(relative.X / (depth * tanHalfFov * aspectRatio), relative.Y / (depth * tanHalfFov))
	end

	it("should return zero for the full viewport", function()
		local offset = CameraUtils.getCameraSubRectShift(10, 35, 16 / 9, FULL_RECT)
		expect(offset.Magnitude).toBeCloseTo(0, 5)
	end)

	it("should move the camera down when the bottom of the screen is covered", function()
		local offset = CameraUtils.getCameraSubRectShift(10, 35, 16 / 9, Rect.new(0, 0, 1, 0.7))
		expect(offset.X).toBeCloseTo(0, 5)
		expect(offset.Y).toBeLessThan(0)
		expect(offset.Z).toEqual(0)
	end)

	-- NDC of the angle bisector between two NDC edges on one axis
	local function getBisectorNdc(lowNdc: number, highNdc: number, tanHalf: number): number
		return math.tan((math.atan(lowNdc * tanHalf) + math.atan(highNdc * tanHalf)) / 2) / tanHalf
	end

	it("should project the subject onto the angle bisector of a bottom-covered rect", function()
		local depth, fovDeg, aspectRatio = 10, 35, 16 / 9
		local offset = CameraUtils.getCameraSubRectShift(depth, fovDeg, aspectRatio, Rect.new(0, 0, 1, 0.7))
		local ndc = projectToNdc(offset, depth, fovDeg, aspectRatio)

		-- Rect spans -0.4 to 1 in NDC. The bisector sits just below its screen-space center of 0.3.
		expect(ndc.X).toBeCloseTo(0, 5)
		expect(ndc.Y).toBeCloseTo(getBisectorNdc(-0.4, 1, math.tan(math.rad(fovDeg) / 2)), 5)
		expect(ndc.Y).toBeLessThan(0.3)
	end)

	it("should project the subject onto the angle bisector of an off-center rect", function()
		local depth, fovDeg, aspectRatio = 25, 50, 0.5
		local rect = Rect.new(0.5, 0.1, 0.9, 0.5)
		local offset = CameraUtils.getCameraSubRectShift(depth, fovDeg, aspectRatio, rect)
		local ndc = projectToNdc(offset, depth, fovDeg, aspectRatio)

		local tanHalfY = math.tan(math.rad(fovDeg) / 2)
		expect(ndc.X).toBeCloseTo(getBisectorNdc(0, 0.8, tanHalfY * aspectRatio), 5)
		expect(ndc.Y).toBeCloseTo(getBisectorNdc(0, 0.8, tanHalfY), 5)
	end)

	it("should scale linearly with depth", function()
		local rect = Rect.new(0, 0, 1, 0.7)
		local near = CameraUtils.getCameraSubRectShift(10, 35, 16 / 9, rect)
		local far = CameraUtils.getCameraSubRectShift(20, 35, 16 / 9, rect)
		expect(far.Y).toBeCloseTo(2 * near.Y, 5)
	end)
end)
