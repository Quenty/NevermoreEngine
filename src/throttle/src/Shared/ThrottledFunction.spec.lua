--!strict
--[[
	@class ThrottledFunction.spec.lua
]]

-- (vibe coded by GPT-5.5)

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local ThrottledFunction = require("ThrottledFunction")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TIMEOUT = 0.05
local WAIT_FOR_TRAILING = TIMEOUT * 2
local WAIT_FOR_DROPPED_TRAILING = TIMEOUT * 1.5

local function recordCalls<T...>()
	local calls = {}

	local function callback(...: T...)
		table.insert(calls, table.pack(...))
	end

	return calls, callback
end

describe("ThrottledFunction", function()
	it("should call immediately when leading is enabled", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = false,
		})

		throttled:Call("first")

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("first")

		throttled:Destroy()
	end)

	it("should drop calls during the cooldown when trailing is disabled", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = false,
		})

		throttled:Call("first")
		throttled:Call("second")
		task.wait(WAIT_FOR_DROPPED_TRAILING)

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("first")

		throttled:Destroy()
	end)

	it("should allow leading calls again after the cooldown when trailing is disabled", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = false,
		})

		throttled:Call("first")
		task.wait(WAIT_FOR_DROPPED_TRAILING)
		throttled:Call("second")

		expect(#calls).toEqual(2)
		expect(calls[1][1]).toEqual("first")
		expect(calls[2][1]).toEqual("second")

		throttled:Destroy()
	end)

	it("should dispatch the latest trailing call after the cooldown", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = true,
		})

		throttled:Call("first")
		throttled:Call("second")
		throttled:Call("third")
		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(2)
		expect(calls[1][1]).toEqual("first")
		expect(calls[2][1]).toEqual("third")

		throttled:Destroy()
	end)

	it("should preserve multiple trailing arguments including nil values", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = true,
			trailing = true,
		})

		throttled:Call("first")
		throttled:Call("second", nil, "third")
		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(2)
		expect(calls[2].n).toEqual(3)
		expect(calls[2][1]).toEqual("second")
		expect(calls[2][3]).toEqual("third")

		throttled:Destroy()
	end)

	it("should delay the first call when leading is disabled and trailing is enabled", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
		})

		throttled:Call("first")

		expect(#calls).toEqual(0)

		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("first")

		throttled:Destroy()
	end)

	it("should update trailing-only calls to the latest arguments before dispatch", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
		})

		throttled:Call("first")
		throttled:Call("second")
		throttled:Call("third")
		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("third")

		throttled:Destroy()
	end)

	it("should cancel pending trailing calls when destroyed", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
		})

		throttled:Call("first")
		throttled:Destroy()
		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(0)
	end)

	it("should only allow the first call to lead when leadingFirstTimeOnly is enabled", function()
		local calls, callback = recordCalls()
		local throttled = ThrottledFunction.new(TIMEOUT, callback, {
			leading = false,
			trailing = true,
			leadingFirstTimeOnly = true,
		})

		throttled:Call("first")

		expect(#calls).toEqual(1)
		expect(calls[1][1]).toEqual("first")

		task.wait(WAIT_FOR_TRAILING)
		throttled:Call("second")

		expect(#calls).toEqual(1)

		task.wait(WAIT_FOR_TRAILING)

		expect(#calls).toEqual(2)
		expect(calls[2][1]).toEqual("second")

		throttled:Destroy()
	end)

	it("should reject a config that cannot dispatch", function()
		local _, callback = recordCalls()

		expect(function()
			ThrottledFunction.new(TIMEOUT, callback, {
				leading = false,
				trailing = false,
			})
		end).toThrow()
	end)

	it("should reject unknown config keys", function()
		local _, callback = recordCalls()

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
	end)

	it("should reject non-boolean config values", function()
		local _, callback = recordCalls()

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
