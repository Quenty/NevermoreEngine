--!strict
local require = require(script.Parent.loader).load(script)

local CountdownTextUtils = require("CountdownTextUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MINUTE = 60
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR

describe("CountdownTextUtils.formatCountdown", function()
	it("should show the zero text at or below zero", function()
		expect(CountdownTextUtils.formatCountdown(0)).toBe("0")
		expect(CountdownTextUtils.formatCountdown(-5)).toBe("0")
		expect(CountdownTextUtils.formatCountdown(0, "Now!")).toBe("Now!")
		expect(CountdownTextUtils.formatCountdown(-5, "Now!")).toBe("Now!")
	end)

	it("should show bare seconds under a minute", function()
		expect(CountdownTextUtils.formatCountdown(1)).toBe("1")
		expect(CountdownTextUtils.formatCountdown(45)).toBe("45")
		expect(CountdownTextUtils.formatCountdown(59)).toBe("59")
		expect(CountdownTextUtils.formatCountdown(60)).toBe("60")
	end)

	it("should show minutes and seconds under an hour", function()
		expect(CountdownTextUtils.formatCountdown(61)).toBe("1:01")
		expect(CountdownTextUtils.formatCountdown(3 * MINUTE + 5)).toBe("3:05")
		expect(CountdownTextUtils.formatCountdown(59 * MINUTE + 59)).toBe("59:59")
		expect(CountdownTextUtils.formatCountdown(HOUR)).toBe("60:00")
		expect(CountdownTextUtils.formatCountdown(HOUR + 59)).toBe("60:59")
		expect(CountdownTextUtils.formatCountdown(HOUR + MINUTE)).toBe("1:01:00")
	end)

	it("should show hours, minutes and seconds under two days", function()
		expect(CountdownTextUtils.formatCountdown(HOUR + 2 * MINUTE + 3)).toBe("1:02:03")
		expect(CountdownTextUtils.formatCountdown(23 * HOUR + 59 * MINUTE + 59)).toBe("23:59:59")
		expect(CountdownTextUtils.formatCountdown(DAY)).toBe("24:00:00")
		expect(CountdownTextUtils.formatCountdown(DAY + 23 * HOUR + 15 * MINUTE)).toBe("47:15:00")
		expect(CountdownTextUtils.formatCountdown(2 * DAY - 1)).toBe("47:59:59")
	end)

	it("should show days from two days on", function()
		expect(CountdownTextUtils.formatCountdown(2 * DAY)).toBe("2 days 0:00:00")
		expect(CountdownTextUtils.formatCountdown(2 * DAY + HOUR + 2 * MINUTE + 3)).toBe("2 days 1:02:03")
		expect(CountdownTextUtils.formatCountdown(45 * DAY + 5)).toBe("45 days 0:00:05")
		expect(CountdownTextUtils.formatCountdown(400 * DAY)).toBe("400 days 0:00:00")
	end)

	it("should localize the days word", function()
		expect(CountdownTextUtils.formatCountdown(3 * DAY + 5, nil, "es-es")).toBe("3 días 0:00:05")
		expect(CountdownTextUtils.formatCountdown(3 * DAY + 5, nil, "de-de")).toBe("3 Tage 0:00:05")
		expect(CountdownTextUtils.formatCountdown(5 * DAY, nil, "ru-ru")).toBe("5 дней 0:00:00")
		expect(CountdownTextUtils.formatCountdown(3 * DAY, nil, "en-gb")).toBe("3 days 0:00:00")
	end)

	it("should truncate fractional seconds", function()
		expect(CountdownTextUtils.formatCountdown(0.5)).toBe("0")
		expect(CountdownTextUtils.formatCountdown(59.9)).toBe("59")
		expect(CountdownTextUtils.formatCountdown(MINUTE + 0.9)).toBe("60")
		expect(CountdownTextUtils.formatCountdown(2 * DAY - 0.1)).toBe("47:59:59")
	end)

	it("should reject bad arguments", function()
		expect(function()
			CountdownTextUtils.formatCountdown("5" :: any)
		end).toThrow("Bad seconds")
		expect(function()
			CountdownTextUtils.formatCountdown(5, 5 :: any)
		end).toThrow("Bad whenAtZeroText")
		expect(function()
			CountdownTextUtils.formatCountdown(5, nil, 5 :: any)
		end).toThrow("Bad locale")
	end)
end)
