--!strict
--[[
	@class Signal.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Maid = require("Maid")
local Signal = require("Signal")
local SignalTestUtils = require("SignalTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local signal = maid:Add(Signal.new())

	return {
		maid = maid,
		signal = signal,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("Signal.Fire", function()
	it("calls every connected handler once", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local firstFires = SignalTestUtils.countFires(controller.maid, controller.signal)

		controller.signal:Fire()

		expect(firstFires()).toBe(1)
		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("calls the most recently connected handler first", function()
		local controller = setup()

		local order: { string } = {}
		controller.signal:Connect(function()
			table.insert(order, "oldest")
		end)
		controller.signal:Connect(function()
			table.insert(order, "middle")
		end)
		controller.signal:Connect(function()
			table.insert(order, "newest")
		end)

		controller.signal:Fire()

		expect(order).toEqual({ "newest", "middle", "oldest" })

		controller:Destroy()
	end)

	it("keeps the remaining handlers in order after one disconnects", function()
		local controller = setup()

		local order: { string } = {}
		controller.signal:Connect(function()
			table.insert(order, "oldest")
		end)
		local middle = controller.signal:Connect(function()
			table.insert(order, "middle")
		end)
		controller.signal:Connect(function()
			table.insert(order, "newest")
		end)

		middle:Disconnect()
		controller.signal:Fire()

		expect(order).toEqual({ "newest", "oldest" })

		controller:Destroy()
	end)

	it("calls a handler connected during a fire first on the next fire", function()
		local controller = setup()

		local order: { string } = {}
		local added = false
		controller.signal:Connect(function()
			table.insert(order, "original")
			if not added then
				added = true
				controller.maid:GiveTask(controller.signal:Connect(function()
					table.insert(order, "added")
				end))
			end
		end)

		controller.signal:Fire()
		controller.signal:Fire()

		expect(order).toEqual({ "original", "added", "original" })

		controller:Destroy()
	end)

	it("passes every argument to every handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.collectFireListTuples(controller.maid, controller.signal)
		local firstFires = SignalTestUtils.collectFireListTuples(controller.maid, controller.signal)

		controller.signal:Fire("a", 2, true)

		expect(firstFires).toEqual({ { "a", 2, true } :: { any } })
		expect(laterFires).toEqual({ { "a", 2, true } :: { any } })

		controller:Destroy()
	end)

	it("passes nil arguments in their positions", function()
		local controller = setup()

		local received: { n: number, [number]: any }? = nil
		controller.signal:Connect(function(...)
			received = table.pack(...)
		end)

		controller.signal:Fire(nil, 2, nil)

		assert(received, "Handler was not called")
		expect(received.n).toBe(3)
		expect(received[1]).toBeNil()
		expect(received[2]).toBe(2)
		expect(received[3]).toBeNil()

		controller:Destroy()
	end)

	it("runs a handler in the memory category it was connected in", function()
		local controller = setup()

		local seenCategory: string? = nil
		-- selene: allow(incorrect_standard_library_use)
		debug.setmemorycategory("SpecSignalCategory")
		controller.signal:Connect(function()
			-- selene: allow(incorrect_standard_library_use)
			seenCategory = debug.getmemorycategory()
		end)
		debug.resetmemorycategory()

		controller.signal:Fire()

		expect(seenCategory).toBe("SpecSignalCategory")

		controller:Destroy()
	end)

	it("still calls later handlers when a handler yields", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		controller.signal:Connect(function()
			coroutine.yield()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("does nothing with no handlers connected", function()
		local controller = setup()

		expect(function()
			controller.signal:Fire()
		end).never.toThrow()

		controller:Destroy()
	end)
end)

describe("Signal.Fire while a handler connects", function()
	it("does not call a handler connected during the fire", function()
		local controller = setup()

		local addedFires = 0
		local added = false
		controller.signal:Connect(function()
			if not added then
				added = true
				controller.maid:GiveTask(controller.signal:Connect(function()
					addedFires += 1
				end))
			end
		end)

		controller.signal:Fire()

		expect(addedFires).toBe(0)

		controller:Destroy()
	end)

	it("calls a handler connected during a fire on the next fire", function()
		local controller = setup()

		local addedFires = 0
		local added = false
		controller.signal:Connect(function()
			if not added then
				added = true
				controller.maid:GiveTask(controller.signal:Connect(function()
					addedFires += 1
				end))
			end
		end)

		controller.signal:Fire()
		controller.signal:Fire()

		expect(addedFires).toBe(1)

		controller:Destroy()
	end)
end)

describe("Signal.Fire while a handler disconnects", function()
	it("still calls later handlers when a handler disconnects itself", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local selfDisconnecting
		selfDisconnecting = controller.signal:Connect(function()
			selfDisconnecting:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("does not call the next handler when a handler disconnects it", function()
		local controller = setup()

		local nextFires = 0
		local nextHandler = controller.signal:Connect(function()
			nextFires += 1
		end)
		controller.signal:Connect(function()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(nextFires).toBe(0)

		controller:Destroy()
	end)

	it("still calls later handlers when a handler disconnects the next handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local nextHandler = controller.signal:Connect(function() end)
		controller.signal:Connect(function()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("skips later handlers when a handler disconnects itself and then the next handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local nextHandler = controller.signal:Connect(function() end)
		local selfDisconnecting
		selfDisconnecting = controller.signal:Connect(function()
			selfDisconnecting:Disconnect()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(0)

		controller:Destroy()
	end)

	it("skips later handlers when a once handler disconnects the next handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local nextHandler = controller.signal:Connect(function() end)
		controller.signal:Once(function()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(0)

		controller:Destroy()
	end)

	it("skips later handlers when code resumed by a wait disconnects the next handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local nextHandler = controller.signal:Connect(function() end)
		task.spawn(function()
			controller.signal:Wait()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(0)

		controller:Destroy()
	end)

	it("still calls later handlers when a handler disconnects the next two handlers", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local secondNext = controller.signal:Connect(function() end)
		local nextHandler = controller.signal:Connect(function() end)
		controller.signal:Connect(function()
			nextHandler:Disconnect()
			secondNext:Disconnect()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("does not call a later handler that a handler disconnects", function()
		local controller = setup()

		local laterFires = 0
		local later = controller.signal:Connect(function()
			laterFires += 1
		end)
		local middleFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		controller.signal:Connect(function()
			later:Disconnect()
		end)

		controller.signal:Fire()

		expect(middleFires()).toBe(1)
		expect(laterFires).toBe(0)

		controller:Destroy()
	end)

	it("still calls later handlers when a handler disconnects one it already called", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local alreadyCalled: any
		controller.signal:Connect(function()
			alreadyCalled:Disconnect()
		end)
		alreadyCalled = controller.signal:Connect(function() end)

		controller.signal:Fire()

		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("still calls later handlers when a once handler is next", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local onceFires = 0
		controller.signal:Once(function()
			onceFires += 1
		end)

		controller.signal:Fire()

		expect(onceFires).toBe(1)
		expect(laterFires()).toBe(1)

		controller:Destroy()
	end)

	it("stops calling handlers once a handler disconnects all of them", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		controller.signal:Connect(function()
			controller.signal:DisconnectAll()
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(0)
		expect(controller.signal:GetConnectionCount()).toBe(0)

		controller:Destroy()
	end)

	it("counts only the handlers still connected after a handler disconnects the next handler", function()
		local controller = setup()

		local countDuringFire: number? = nil
		controller.signal:Connect(function() end)
		local nextHandler = controller.signal:Connect(function() end)
		controller.signal:Connect(function()
			nextHandler:Disconnect()
			countDuringFire = controller.signal:GetConnectionCount()
		end)

		controller.signal:Fire()

		expect(countDuringFire).toBe(2)

		controller:Destroy()
	end)
end)

describe("Signal.Fire while a handler fires the same signal", function()
	it("calls every handler for both the outer and the re-entrant fire", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local reentered = false
		controller.signal:Connect(function()
			if not reentered then
				reentered = true
				controller.signal:Fire()
			end
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(2)

		controller:Destroy()
	end)

	it("runs the whole re-entrant fire before the outer fire continues", function()
		local controller = setup()

		local order: { string } = {}
		controller.signal:Connect(function()
			table.insert(order, "c")
		end)
		controller.signal:Connect(function()
			table.insert(order, "b")
		end)
		local reentered = false
		controller.signal:Connect(function()
			table.insert(order, "a")
			if not reentered then
				reentered = true
				controller.signal:Fire()
			end
		end)

		controller.signal:Fire()

		expect(order).toEqual({ "a", "a", "b", "c", "b", "c" })

		controller:Destroy()
	end)

	it("calls a handler connected during the outer fire from the re-entrant fire only", function()
		local controller = setup()

		local order: { string } = {}
		controller.signal:Connect(function()
			table.insert(order, "b")
		end)
		local reentered = false
		controller.signal:Connect(function()
			table.insert(order, "a")
			if not reentered then
				reentered = true
				controller.maid:GiveTask(controller.signal:Connect(function()
					table.insert(order, "added")
				end))
				controller.signal:Fire()
			end
		end)

		controller.signal:Fire()

		expect(order).toEqual({ "a", "added", "a", "b", "b" })

		controller:Destroy()
	end)

	it("skips in the outer fire a handler that the re-entrant fire disconnects further down", function()
		local controller = setup()

		local order: { string } = {}
		local c = controller.signal:Connect(function()
			table.insert(order, "c")
		end)
		controller.signal:Connect(function()
			table.insert(order, "b")
		end)
		local reentered = false
		controller.signal:Connect(function()
			table.insert(order, "a")
			if not reentered then
				reentered = true
				controller.signal:Fire()
				c:Disconnect()
			end
		end)

		controller.signal:Fire()

		expect(order).toEqual({ "a", "a", "b", "c", "b" })

		controller:Destroy()
	end)

	it("still calls later handlers when a re-entrant fire disconnects the next handler", function()
		local controller = setup()

		local laterFires = SignalTestUtils.countFires(controller.maid, controller.signal)
		local nextHandler = controller.signal:Connect(function() end)
		local reentered = false
		controller.signal:Connect(function()
			if not reentered then
				reentered = true
				controller.signal:Fire()
				nextHandler:Disconnect()
			end
		end)

		controller.signal:Fire()

		expect(laterFires()).toBe(2)

		controller:Destroy()
	end)
end)

describe("Signal.Once", function()
	it("calls the handler only on the first fire", function()
		local controller = setup()

		local onceFires = 0
		controller.signal:Once(function()
			onceFires += 1
		end)

		controller.signal:Fire()
		controller.signal:Fire()

		expect(onceFires).toBe(1)

		controller:Destroy()
	end)

	it("calls the handler only once when it fires the signal again", function()
		local controller = setup()

		local onceFires = 0
		controller.signal:Once(function()
			onceFires += 1
			controller.signal:Fire()
		end)

		controller.signal:Fire()

		expect(onceFires).toBe(1)

		controller:Destroy()
	end)

	it("does not call the handler once disconnected before the fire", function()
		local controller = setup()

		local onceFires = 0
		local connection = controller.signal:Once(function()
			onceFires += 1
		end)

		connection:Disconnect()
		controller.signal:Fire()

		expect(onceFires).toBe(0)

		controller:Destroy()
	end)
end)

describe("Signal.Wait", function()
	it("resumes with the fired arguments", function()
		local controller = setup()

		local received: { any }? = nil
		task.spawn(function()
			received = table.pack(controller.signal:Wait())
		end)

		controller.signal:Fire("a", 2)

		expect(received).toEqual({ "a" :: any, 2, n = 2 })
		expect(controller.signal:GetConnectionCount()).toBe(0)

		controller:Destroy()
	end)

	it("stays connected after the waiting thread is cancelled", function()
		local controller = setup()

		local waitingThread = task.spawn(function()
			controller.signal:Wait()
		end)
		task.cancel(waitingThread)

		expect(controller.signal:GetConnectionCount()).toBe(1)

		controller:Destroy()
	end)
end)

describe("Signal.Destroy", function()
	it("disconnects every handler", function()
		local controller = setup()

		local connection = controller.signal:Connect(function() end)

		controller.signal:Destroy()

		expect(connection:IsConnected()).toBe(false)

		controller:Destroy()
	end)

	it("still connects and fires handlers afterwards", function()
		local controller = setup()

		controller.signal:Destroy()
		local fires = SignalTestUtils.countFires(controller.maid, controller.signal)

		controller.signal:Fire()

		expect(fires()).toBe(1)

		controller:Destroy()
	end)
end)

describe("Signal.DisconnectAll", function()
	it("disconnects every handler", function()
		local controller = setup()

		local first = controller.signal:Connect(function() end)
		local second = controller.signal:Connect(function() end)

		controller.signal:DisconnectAll()

		expect(first:IsConnected()).toBe(false)
		expect(second:IsConnected()).toBe(false)
		expect(controller.signal:GetConnectionCount()).toBe(0)

		controller:Destroy()
	end)
end)

describe("Signal Connection.Disconnect", function()
	it("reports the connection as disconnected", function()
		local controller = setup()

		local connection = controller.signal:Connect(function() end)

		connection:Disconnect()

		expect(connection:IsConnected()).toBe(false)

		controller:Destroy()
	end)

	it("reports Connected like an RBXScriptConnection", function()
		local controller = setup()

		local connection = controller.signal:Connect(function() end)
		expect(connection.Connected).toBe(true)

		connection:Disconnect()

		expect(connection.Connected).toBe(false)

		controller:Destroy()
	end)

	it("reports Connected as false once the signal is destroyed", function()
		local controller = setup()

		local connection = controller.signal:Connect(function() end)

		controller.signal:Destroy()

		expect(connection.Connected).toBe(false)

		controller:Destroy()
	end)

	it("can be called twice", function()
		local controller = setup()

		local connection = controller.signal:Connect(function() end)

		connection:Disconnect()

		expect(function()
			connection:Disconnect()
		end).never.toThrow()

		controller:Destroy()
	end)

	it("holds no references once disconnected outside a fire", function()
		local controller = setup()

		controller.signal:Connect(function() end)
		local middle = controller.signal:Connect(function() end)
		controller.signal:Connect(function() end)

		middle:Disconnect()

		expect(next(middle :: any)).toBeNil()

		controller:Destroy()
	end)

	it("holds no references once the fire that disconnected it finishes", function()
		local controller = setup()

		controller.signal:Connect(function() end)
		local nextHandler = controller.signal:Connect(function() end)
		controller.signal:Connect(function()
			nextHandler:Disconnect()
		end)

		controller.signal:Fire()

		expect(next(nextHandler :: any)).toBeNil()

		controller:Destroy()
	end)

	it("keeps the others firing in order after the oldest disconnects", function()
		local controller = setup()

		local order: { string } = {}
		local oldest = controller.signal:Connect(function()
			table.insert(order, "oldest")
		end)
		controller.signal:Connect(function()
			table.insert(order, "middle")
		end)
		controller.signal:Connect(function()
			table.insert(order, "newest")
		end)

		oldest:Disconnect()
		controller.signal:Fire()

		expect(order).toEqual({ "newest", "middle" })

		controller:Destroy()
	end)

	it("keeps the others firing in order after the newest disconnects", function()
		local controller = setup()

		local order: { string } = {}
		controller.signal:Connect(function()
			table.insert(order, "oldest")
		end)
		controller.signal:Connect(function()
			table.insert(order, "middle")
		end)
		local newest = controller.signal:Connect(function()
			table.insert(order, "newest")
		end)

		newest:Disconnect()
		controller.signal:Fire()

		expect(order).toEqual({ "middle", "oldest" })

		controller:Destroy()
	end)

	it("leaves the signal empty and usable after disconnecting every connection oldest first", function()
		local controller = setup()

		local connections: { any } = {}
		for index = 1, 5 do
			connections[index] = controller.signal:Connect(function() end)
		end

		for _, connection in connections do
			connection:Disconnect()
		end

		expect(controller.signal:GetConnectionCount()).toBe(0)

		local fires = SignalTestUtils.countFires(controller.maid, controller.signal)
		controller.signal:Fire()

		expect(fires()).toBe(1)

		controller:Destroy()
	end)

	it("leaves the signal empty and usable after disconnecting every connection newest first", function()
		local controller = setup()

		local connections: { any } = {}
		for index = 1, 5 do
			connections[index] = controller.signal:Connect(function() end)
		end

		for index = #connections, 1, -1 do
			connections[index]:Disconnect()
		end

		expect(controller.signal:GetConnectionCount()).toBe(0)

		local fires = SignalTestUtils.countFires(controller.maid, controller.signal)
		controller.signal:Fire()

		expect(fires()).toBe(1)

		controller:Destroy()
	end)
end)
