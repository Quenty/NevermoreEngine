--!strict
--[[
	@class record-viewport.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local EncodingService = game:GetService("EncodingService")

local ActionReply = require("action-reply")
local ActionRouter = require("ActionRouter")
local FrameRecorder = require("frame-recorder")
local Jest = require("Jest")
local RecordViewportAction = require("record-viewport")
local ViewportCapture = require("viewport-capture")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type SetupOptions = {
	captureDelay: number?,
	isClient: boolean?,
	-- Gives the router a PNG encoder, as the plugin does
	hasPng: boolean?,
	-- Content ids whose EditableImage fails to load
	failingContentIds: { string }?,
}

--[[
	Fakes whose captures come back `captureDelay` frames after they are asked
	for, and which, like CaptureService, drop requests made while one is in
	flight without ever calling them back. The viewport is 2x1.
]]
local function setup(options: SetupOptions?): any
	local router = ActionRouter.new()
	if options and options.hasPng then
		router:SetVendorPng({
			encode = function(_pixels: buffer, _options: any)
				return buffer.fromstring("PNG!")
			end,
		})
	end
	RecordViewportAction.register(router, function() end)
	FrameRecorder.register(router)
	ViewportCapture.register(router)
	ActionReply.register(router)

	local captureDelay = if options and options.captureDelay then options.captureDelay else 0
	local failing = if options and options.failingContentIds then options.failingContentIds else {}
	local stepCallback: ((number) -> ())? = nil
	local waitingCaptures: { { framesLeft: number, deliver: () -> () } } = {}
	local captureCount = 0
	local stepCount = 0

	local runService = {
		IsClient = function()
			return not (options and options.isClient == false)
		end,
		BindToRenderStep = function(_self, _name: string, _priority: number, callback: (number) -> ())
			stepCallback = callback
		end,
		UnbindFromRenderStep = function()
			stepCallback = nil
		end,
	}

	local services = {
		runService = runService,
		camera = { ViewportSize = Vector2.new(2, 1) },
		captureService = {
			CaptureScreenshot = function(_self, onReady: (string) -> ())
				if #waitingCaptures > 0 then
					return
				end
				captureCount += 1
				local contentId = `rbxtemp://{captureCount}`
				if captureDelay == 0 then
					onReady(contentId)
				else
					table.insert(waitingCaptures, {
						framesLeft = captureDelay,
						deliver = function()
							onReady(contentId)
						end,
					})
				end
			end,
		},
		assetService = {
			CreateEditableImageAsync = function(_self, content: any)
				if table.find(failing, content.Uri) then
					error("could not load")
				end
				return {
					Size = Vector2.new(2, 1),
					ReadPixelsBuffer = function()
						return buffer.fromstring("\255\0\0\255\0\0\255\255")
					end,
					Destroy = function() end,
				}
			end,
		},
		encodingService = EncodingService,
	}

	local function deliverCaptures()
		for index = #waitingCaptures, 1, -1 do
			local waiting = waitingCaptures[index]
			waiting.framesLeft -= 1
			if waiting.framesLeft <= 0 then
				table.remove(waitingCaptures, index)
				waiting.deliver()
			end
		end
	end

	return {
		getCaptureCount = function(): number
			return captureCount
		end,
		getStepCount = function(): number
			return stepCount
		end,
		record = function(payload: { [string]: any }, frameCount: number): any
			local result = nil
			task.spawn(function()
				result = RecordViewportAction._recordAsync(payload, services :: any)
			end)
			for _ = 1, frameCount do
				if not stepCallback then
					break
				end
				deliverCaptures()
				stepCount += 1
				(stepCallback :: any)(0.1)
			end
			-- Lets the last capture come back after the window
			local deadline = os.clock() + 5
			while result == nil and os.clock() < deadline do
				deliverCaptures()
				task.wait()
			end
			return result
		end,
	}
end

local function decode(data: string): string
	return buffer.tostring(EncodingService:Base64Decode(buffer.fromstring(data)))
end

describe("recordViewport", function()
	it("should read every capture after the window, with its frame's time", function()
		local controller = setup()

		local result = controller.record({ duration = 0.2 }, 10)

		expect(#result.frames).toEqual(3)
		expect(result.frames[1].t).toEqual(0)
		expect(result.frames[2].frame).toEqual(1)
		expect(result.frames[3].t).toBeCloseTo(0.2)
		expect(result.frames[1].width).toEqual(2)
		expect(#result.skipped).toEqual(0)
	end)

	it("should send raw RGBA without a PNG encoder", function()
		local controller = setup()

		local result = controller.record({ duration = 0 }, 2)

		expect(result.frames[1].format).toEqual("rgba")
		expect(#decode(result.frames[1].data)).toEqual(8)
	end)

	it("should send PNG with the plugin's encoder", function()
		local controller = setup({ hasPng = true })

		local result = controller.record({ duration = 0 }, 2)

		expect(result.frames[1].format).toEqual("png")
		expect(decode(result.frames[1].data)).toEqual("PNG!")
	end)

	it("should leave out the requests CaptureService dropped", function()
		local controller = setup({ captureDelay = 2 })

		local result = controller.record({ duration = 0.5 }, 20)

		-- Frames 0..5 each ask; the ones asked while a capture is in flight are dropped
		expect(result.requested).toEqual(6)
		expect(controller.getCaptureCount()).toEqual(3)
		expect(#result.frames).toEqual(3)
		expect(result.frames[2].frame).toEqual(2)
		expect(result.frames[2].t).toBeCloseTo(0.2)
	end)

	it("should not wait out the full second for requests that were dropped", function()
		local controller = setup({ captureDelay = 2 })

		local startedAt = os.clock()
		controller.record({ duration = 0.5 }, 20)

		expect(os.clock() - startedAt < 0.8).toEqual(true)
	end)

	it("should skip a capture that fails to read and say why", function()
		local controller = setup({ failingContentIds = { "rbxtemp://2" } })

		local result = controller.record({ duration = 0.2 }, 10)

		expect(#result.frames).toEqual(2)
		expect(#result.skipped).toEqual(1)
		expect(result.skipped[1].frame).toEqual(1)
		expect(result.skipped[1].reason).toMatch("EditableImage")
	end)

	it("should crop to the region", function()
		local controller = setup()

		local result = controller.record({ duration = 0, region = { 1, 0, 1, 1 } }, 2)

		expect(result.frames[1].width).toEqual(1)
		expect(result.frames[1].height).toEqual(1)
	end)

	it("should refuse a region outside the viewport before running anything", function()
		local controller = setup()

		local result = controller.record({ duration = 1, region = { 10, 10, 5, 5 } }, 5)

		expect(result.code).toEqual("INVALID_REGION")
		expect(result.message).toMatch("2x1")
		expect(controller.getStepCount()).toEqual(0)
	end)

	it("should refuse to record a server", function()
		local controller = setup({ isClient = false })

		local result = controller.record({ duration = 0.2 }, 1)

		expect(result.code).toEqual("CAPABILITY_NOT_SUPPORTED")
	end)
end)
