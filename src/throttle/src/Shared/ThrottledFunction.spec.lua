--!strict
--[[
	@class ThrottledFunction.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local ThrottledFunction = require("ThrottledFunction")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it
local jest = Jest.Globals.jest

local TIMEOUT = 1
local TIMEOUT_MS = TIMEOUT * 1000

local function recordCalls<T...>()
	local calls = {}

	local function callback(...: T...)
		table.insert(calls, table.pack(...))
	end

	return calls, callback
end

describe("ThrottledFunction", function()
	it("should drop cooldown calls when trailing is disabled", function()
		jest.useFakeTimers()

		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = false,
		})

		throttled:Call("first")
		throttled:Call("too fast, drop me")

		jest.advanceTimersByTime(TIMEOUT_MS)

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("first")

		throttled:Destroy()
		jest.useRealTimers()
	end)

	it("should dispatch the latest trailing call with all arguments", function()
		jest.useFakeTimers()

		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = true,
		})

		throttled:Call("first")
		throttled:Call("second but will be overwritten by the next call...")
		throttled:Call("third", nil, "fourth")
		jest.advanceTimersByTime(TIMEOUT_MS)

		expect(#calls).toEqual(2)
		expect(calls[1][1]).toEqual("first")
		expect(calls[2].n).toEqual(3)
		expect(calls[2][1]).toEqual("third")
		expect(calls[2][2]).toEqual(nil)
		expect(calls[2][3]).toEqual("fourth")

		throttled:Destroy()
		jest.useRealTimers()
	end)

	it("should delay trailing-only calls and keep the latest arguments", function()
		jest.useFakeTimers()

		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
		})

		throttled:Call("first but will be overwritten by the next call...")
		throttled:Call("second, final and dispatched")

		expect(#calls).toEqual(0)

		jest.advanceTimersByTime(TIMEOUT_MS)

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("second, final and dispatched")

		throttled:Destroy()
		jest.useRealTimers()
	end)

	it("should cancel pending trailing calls when destroyed, not calling after destroyed", function()
		jest.useFakeTimers()

		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
		})

		throttled:Call("first but will be destroyed and thus discarded")
		throttled:Destroy()
		jest.advanceTimersByTime(TIMEOUT_MS)

		expect(#calls).toEqual(0)

		jest.useRealTimers()
	end)

	it("should reject if leading and trailing are both false", function()
		local _, callback = recordCalls()

		expect(function()
			ThrottledFunction.new(TIMEOUT, callback, {
				leading = false,
				trailing = false,
			})
		end).toThrow()

		expect(function()
			ThrottledFunction.new(
				TIMEOUT,
				callback,
				{
					leading = true,
					trailing = true,
					notAConfigKey = true,
				} :: any
			)
		end).toThrow()

		expect(function()
			ThrottledFunction.new(
				TIMEOUT,
				callback,
				{
					leading = "yes",
				} :: any
			)
		end).toThrow()
	end)
end)
