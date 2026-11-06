--!strict
--[[
	@class frame-recorder.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local FrameRecorder = require("frame-recorder")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

--[[
	A RunService whose frames the test steps by hand. Without render stepping,
	BindToRenderStep throws, as it does on a server.
]]
local function createRunService(hasRenderStep: boolean?): any
	local callbacks: { [string]: (number) -> () } = {}
	local runService = {}

	function runService.BindToRenderStep(_self, name: string, _priority: number, callback: (number) -> ())
		if hasRenderStep == false then
			error("BindToRenderStep can only be used on the client")
		end
		callbacks[name] = callback
	end

	function runService.UnbindFromRenderStep(_self, name: string)
		callbacks[name] = nil
	end

	runService.Heartbeat = {
		Connect = function(_self, callback: (number) -> ())
			callbacks.heartbeat = callback
			return {
				Disconnect = function()
					callbacks.heartbeat = nil
				end,
			}
		end,
	}

	function runService.step(deltaTime: number)
		for _, callback in table.clone(callbacks) do
			callback(deltaTime)
		end
	end

	function runService.isStepping(): boolean
		return next(callbacks) ~= nil
	end

	return runService
end

--[[
	Starts a recording, steps `frameCount` frames of `deltaTime`, and returns
	the result (nil if it had not finished) with every frame `onFrame` saw.
]]
local function record(options: { [string]: any }, frameCount: number, deltaTime: number, runService: any?): any
	local stepper = runService or createRunService()
	local seen = {}
	local result = nil

	local recordOptions = table.clone(options)
	recordOptions.onFrame = options.onFrame
		or function(t: number, frame: number)
			table.insert(seen, { t = t, frame = frame })
		end

	task.spawn(function()
		result = FrameRecorder.recordAsync(recordOptions :: any, { runService = stepper })
	end)
	for _ = 1, frameCount do
		stepper.step(deltaTime)
	end

	return {
		result = result,
		seen = seen,
		isStepping = stepper.isStepping(),
	}
end

describe("FrameRecorder.recordAsync", function()
	it("should record every frame through the first one at or past the duration", function()
		local recording = record({ duration = 0.25 }, 10, 0.1)

		expect(recording.result.recorded).toEqual(4)
		expect(recording.result.frameCount).toEqual(4)
		expect(recording.result.clock).toEqual("renderStep")
		expect(recording.seen[1]).toEqual({ t = 0, frame = 0 })
		expect(recording.seen[4].frame).toEqual(3)
		expect(recording.seen[4].t).toBeCloseTo(0.3)
		expect(recording.isStepping).toEqual(false)
	end)

	it("should run the trigger in frame 0", function()
		local triggeredAtFrame = nil
		local seenFrames = 0
		local recording = record({
			duration = 0.1,
			trigger = function()
				triggeredAtFrame = seenFrames
			end,
			onFrame = function()
				seenFrames += 1
			end,
		}, 5, 0.1)

		expect(triggeredAtFrame).toEqual(0)
		expect(recording.result.recorded).toEqual(2)
	end)

	it("should record only as often as fps asks", function()
		local recording = record({ duration = 1, fps = 10 }, 100, 1 / 60)

		-- Frame 0, then each 0.1s through 1s
		expect(recording.result.recorded).toEqual(11)
		expect(recording.seen[2].t).toBeCloseTo(0.1, 1)
	end)

	it("should stop at maxFrames and say so", function()
		local recording = record({ duration = 10, maxFrames = 3 }, 10, 0.1)

		expect(recording.result.recorded).toEqual(3)
		expect(recording.result.truncated).toEqual(true)
		expect(recording.isStepping).toEqual(false)
	end)

	it("should stop with the error when onFrame throws", function()
		local recording = record({
			duration = 10,
			onFrame = function()
				error("bad frame", 0)
			end,
		}, 10, 0.1)

		expect(recording.result.error).toEqual("bad frame")
		expect(recording.isStepping).toEqual(false)
	end)

	it("should stop with the error when the trigger throws", function()
		local recording = record({
			duration = 10,
			trigger = function()
				error("boom")
			end,
		}, 10, 0.1)

		expect(recording.result.error).toMatch("Trigger failed")
		expect(recording.result.error).toMatch("boom")
		expect(recording.isStepping).toEqual(false)
	end)

	it("should step on Heartbeat where render stepping is not available", function()
		local recording = record({ duration = 0.2 }, 10, 0.1, createRunService(false))

		expect(recording.result.clock).toEqual("heartbeat")
		expect(recording.result.recorded).toEqual(3)
		expect(recording.isStepping).toEqual(false)
	end)
end)

describe("FrameRecorder.compileTrigger", function()
	it("should return nothing without a source", function()
		local trigger, err = FrameRecorder.compileTrigger({}, nil)

		expect(trigger).toBeNil()
		expect(err).toBeNil()
	end)

	it("should compile through the router's Compile", function()
		local router = {
			Compile = function(_self, source: string)
				return function()
					return source
				end, nil
			end,
		}

		local trigger, err = FrameRecorder.compileTrigger(router, "x = 1")

		expect(err).toBeNil()
		expect((trigger :: any)()).toEqual("x = 1")
	end)

	it("should return the compile error", function()
		local router = {
			Compile = function()
				return nil, "syntax error"
			end,
		}

		local trigger, err = FrameRecorder.compileTrigger(router, "x =")

		expect(trigger).toBeNil()
		expect(err).toEqual("syntax error")
	end)
end)
