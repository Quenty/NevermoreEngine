--!strict
--[[
	@class StepUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Jest = require("Jest")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	newBindable: () -> BindableEvent,
	bind: (RBXScriptSignal, (...any) -> boolean) -> ((...any) -> (), () -> ()),
	bindRenderStep: ((...any) -> boolean) -> ((...any) -> (), () -> ()),
	bindStepped: ((...any) -> boolean) -> ((...any) -> (), () -> ()),
	track: (() -> ()) -> () -> (),
	stepFrames: (number) -> (),
	destroy: () -> (),
}

local function setup(): Controller
	local instances: { Instance } = {}
	local cleanups: { () -> () } = {}

	local function track(cleanup: () -> ()): () -> ()
		table.insert(cleanups, cleanup)
		return cleanup
	end

	local controller: Controller = {
		newBindable = function()
			local bindable = Instance.new("BindableEvent")
			table.insert(instances, bindable)
			return bindable
		end,

		bind = function(signal, update)
			local connect, disconnect = StepUtils.bindToSignal(signal, update)
			track(disconnect)
			return connect, disconnect
		end,

		bindRenderStep = function(update)
			local connect, disconnect = StepUtils.bindToRenderStep(update)
			track(disconnect)
			return connect, disconnect
		end,

		bindStepped = function(update)
			local connect, disconnect = StepUtils.bindToStepped(update)
			track(disconnect)
			return connect, disconnect
		end,

		track = track,

		stepFrames = function(count: number)
			for _ = 1, count do
				task.wait()
			end
		end,

		destroy = function()
			for _, cleanup in cleanups do
				cleanup()
			end
			for _, inst in instances do
				inst:Destroy()
			end
		end,
	}

	return controller
end

describe("StepUtils.getAnimationStepSignal", function()
	it("returns a signal", function()
		local controller = setup()

		expect(typeof(StepUtils.getAnimationStepSignal())).toBe("RBXScriptSignal")

		controller.destroy()
	end)

	it("falls back to Heartbeat off a running client", function()
		local controller = setup()

		expect(StepUtils.getAnimationStepSignal()).toBe(RunService.Heartbeat)

		controller.destroy()
	end)

	it("returns a signal that actually fires here", function()
		local controller = setup()

		local fired = false
		local conn = StepUtils.getAnimationStepSignal():Connect(function()
			fired = true
		end)
		controller.track(function()
			conn:Disconnect()
		end)

		controller.stepFrames(2)

		expect(fired).toBe(true)

		controller.destroy()
	end)
end)

describe("StepUtils.getSteppedSignal", function()
	it("returns a signal", function()
		local controller = setup()

		expect(typeof(StepUtils.getSteppedSignal())).toBe("RBXScriptSignal")

		controller.destroy()
	end)

	it("falls back to Heartbeat on a non-running DataModel", function()
		local controller = setup()

		expect(StepUtils.getSteppedSignal()).toBe(RunService.Heartbeat)
		expect(StepUtils.getSteppedSignal()).never.toBe(RunService.Stepped)

		controller.destroy()
	end)

	it("returns a signal that actually fires here", function()
		local controller = setup()

		local fired = false
		local conn = StepUtils.getSteppedSignal():Connect(function()
			fired = true
		end)
		controller.track(function()
			conn:Disconnect()
		end)

		controller.stepFrames(2)

		expect(fired).toBe(true)

		controller.destroy()
	end)
end)

describe("StepUtils.bindToSignal", function()
	it("invokes the update immediately on connect", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect = controller.bind(bindable.Event, function()
			calls += 1
			return false
		end)

		connect()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("does not connect when the first update returns false", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect = controller.bind(bindable.Event, function()
			calls += 1
			return false
		end)

		connect()
		bindable:Fire()
		bindable:Fire()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("keeps invoking the update while it returns true", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect = controller.bind(bindable.Event, function()
			calls += 1
			return calls < 3
		end)

		connect()
		bindable:Fire()
		bindable:Fire()

		expect(calls).toBe(3)

		controller.destroy()
	end)

	it("stops invoking the update once it returns false", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect = controller.bind(bindable.Event, function()
			calls += 1
			return calls < 2
		end)

		connect()
		bindable:Fire()
		bindable:Fire()
		bindable:Fire()

		expect(calls).toBe(2)

		controller.destroy()
	end)

	it("forwards the connect arguments to every later update", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local seen = {}
		local connect = controller.bind(bindable.Event, function(arg)
			table.insert(seen, arg)
			return #seen < 3
		end)

		connect("self")
		bindable:Fire()
		bindable:Fire()

		expect(seen).toEqual({ "self", "self", "self" })

		controller.destroy()
	end)

	it("ignores the signal's own arguments", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local seen = {}
		local connect = controller.bind(bindable.Event, function(arg)
			table.insert(seen, { value = arg })
			return #seen < 2
		end)

		connect()
		bindable:Fire("fromSignal")

		expect(seen).toEqual({ { value = nil }, { value = nil } })

		controller.destroy()
	end)

	it("ignores a repeated connect while already connected", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect = controller.bind(bindable.Event, function()
			calls += 1
			return true
		end)

		connect()
		connect()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("reconnects after an explicit disconnect", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local connect, disconnect = controller.bind(bindable.Event, function()
			calls += 1
			return true
		end)

		connect()
		disconnect()
		bindable:Fire()
		expect(calls).toBe(1)

		connect()
		bindable:Fire()

		expect(calls).toBe(3)

		controller.destroy()
	end)

	it("tolerates disconnect before connect and repeated disconnects", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local _connect, disconnect = controller.bind(bindable.Event, function()
			return true
		end)

		expect(function()
			disconnect()
			disconnect()
		end).never.toThrow()

		controller.destroy()
	end)

	it("throws on something that is not a signal", function()
		local controller = setup()

		expect(function()
			(StepUtils :: any).bindToSignal({}, function()
				return false
			end)
		end).toThrow()

		controller.destroy()
	end)

	it("throws on a non-function update", function()
		local controller = setup()
		local bindable = controller.newBindable()

		expect(function()
			(StepUtils :: any).bindToSignal(bindable.Event, "update")
		end).toThrow()

		controller.destroy()
	end)
end)

describe("StepUtils.bindToRenderStep", function()
	it("drives the update off the animation step signal", function()
		local controller = setup()

		local calls = 0
		local connect = controller.bindRenderStep(function()
			calls += 1
			return calls < 3
		end)

		connect()
		controller.stepFrames(5)

		expect(calls).toBe(3)

		controller.destroy()
	end)

	it("does not bind when the first update returns false", function()
		local controller = setup()

		local calls = 0
		local connect = controller.bindRenderStep(function()
			calls += 1
			return false
		end)

		connect()
		controller.stepFrames(3)

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("stops driving the update after disconnect", function()
		local controller = setup()

		local calls = 0
		local connect, disconnect = controller.bindRenderStep(function()
			calls += 1
			return true
		end)

		connect()
		controller.stepFrames(2)
		disconnect()

		local afterDisconnect = calls
		controller.stepFrames(3)

		expect(calls).toBe(afterDisconnect)

		controller.destroy()
	end)
end)

describe("StepUtils.bindToStepped", function()
	it("invokes the update immediately on connect", function()
		local controller = setup()

		local calls = 0
		local connect = controller.bindStepped(function()
			calls += 1
			return false
		end)

		connect()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("tolerates disconnect before connect", function()
		local controller = setup()

		local _connect, disconnect = controller.bindStepped(function()
			return true
		end)

		expect(function()
			disconnect()
		end).never.toThrow()

		controller.destroy()
	end)
end)

describe("StepUtils.deferWait", function()
	it("resumes only after already-queued deferrals run", function()
		local controller = setup()

		local order = {}
		task.defer(function()
			table.insert(order, "deferred")
		end)

		StepUtils.deferWait()
		table.insert(order, "resumed")

		expect(order).toEqual({ "deferred", "resumed" })

		controller.destroy()
	end)
end)

describe("StepUtils.onceAtEvent", function()
	it("invokes the function on the next event", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		controller.track(StepUtils.onceAtEvent(bindable.Event, function()
			calls += 1
		end))

		bindable:Fire()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("passes the event arguments through", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local seen: any = nil
		controller.track(StepUtils.onceAtEvent(bindable.Event, function(value: any)
			seen = value
		end))

		bindable:Fire("payload")

		expect(seen).toBe("payload")

		controller.destroy()
	end)

	it("only invokes the function once", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		controller.track(StepUtils.onceAtEvent(bindable.Event, function()
			calls += 1
		end))

		bindable:Fire()
		bindable:Fire()

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("does not invoke the function once cancelled", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local calls = 0
		local cancel = StepUtils.onceAtEvent(bindable.Event, function()
			calls += 1
		end)

		cancel()
		bindable:Fire()

		expect(calls).toBe(0)

		controller.destroy()
	end)

	it("tolerates cancelling after the function ran", function()
		local controller = setup()
		local bindable = controller.newBindable()

		local cancel = StepUtils.onceAtEvent(bindable.Event, function() end)
		bindable:Fire()

		expect(function()
			cancel()
			cancel()
		end).never.toThrow()

		controller.destroy()
	end)

	it("throws on a non-function", function()
		local controller = setup()
		local bindable = controller.newBindable()

		expect(function()
			(StepUtils :: any).onceAtEvent(bindable.Event, "func")
		end).toThrow()

		controller.destroy()
	end)
end)

describe("StepUtils.onceAtRenderStepped", function()
	it("invokes the function once on the animation step signal", function()
		local controller = setup()

		local calls = 0
		controller.track(StepUtils.onceAtRenderStepped(function()
			calls += 1
		end))

		controller.stepFrames(3)

		expect(calls).toBe(1)

		controller.destroy()
	end)

	it("does not invoke the function once cancelled", function()
		local controller = setup()

		local calls = 0
		local cancel = StepUtils.onceAtRenderStepped(function()
			calls += 1
		end)

		cancel()
		controller.stepFrames(3)

		expect(calls).toBe(0)

		controller.destroy()
	end)
end)

describe("StepUtils.onceAtStepped", function()
	it("returns a cancel function that is safe to call twice", function()
		local controller = setup()

		local calls = 0
		local cancel = StepUtils.onceAtStepped(function()
			calls += 1
		end)

		expect(function()
			cancel()
			cancel()
		end).never.toThrow()
		expect(calls).toBe(0)

		controller.destroy()
	end)
end)

describe("StepUtils.onceAtRenderPriority", function()
	it("returns a cancel function that is safe to call twice", function()
		local controller = setup()

		local cancel = StepUtils.onceAtRenderPriority(Enum.RenderPriority.Last.Value, function() end)

		expect(function()
			cancel()
			cancel()
		end).never.toThrow()

		controller.destroy()
	end)

	it("throws on a non-number priority", function()
		local controller = setup()

		expect(function()
			(StepUtils :: any).onceAtRenderPriority("high", function() end)
		end).toThrow()

		controller.destroy()
	end)

	it("throws on a non-function", function()
		local controller = setup()

		expect(function()
			(StepUtils :: any).onceAtRenderPriority(100, "func")
		end).toThrow()

		controller.destroy()
	end)
end)
