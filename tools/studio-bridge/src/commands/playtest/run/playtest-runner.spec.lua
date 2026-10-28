--!strict
--[[
	@class playtest-runner.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlaytestRunner = require("playtest-runner")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(testArgs: any)
	local ended = {}
	local runner = Instance.new("Folder")
	runner:SetAttribute("RunnerId", "runner-1")

	local studioTestService = {
		GetTestArgs = function()
			return testArgs
		end,
		EndTest = function(_self, value)
			table.insert(ended, value)
		end,
	}

	return {
		runner = runner,
		studioTestService = studioTestService,
		ended = ended,
		Destroy = function()
			runner:Destroy()
		end,
	}
end

describe("PlaytestRunner.runAsync()", function()
	it("should do nothing in a playtest it was not planted for", function()
		local controller = setup({ studioBridgeRunnerId = "someone-else" })

		PlaytestRunner.runAsync(controller.runner, controller.studioTestService, game:GetService("Players"))

		expect(controller.ended).toEqual({})
		controller:Destroy()
	end)

	it("should end the playtest with a load error when the code module is missing", function()
		local controller = setup({ studioBridgeRunnerId = "runner-1" })

		PlaytestRunner.runAsync(controller.runner, controller.studioTestService, game:GetService("Players"))

		expect(#controller.ended).toEqual(1)
		expect(controller.ended[1].success).toEqual(false)
		expect(controller.ended[1].code).toEqual("SCRIPT_LOAD_ERROR")
		controller:Destroy()
	end)
end)

describe("PlaytestRunner._serializeReturnValues()", function()
	it("should keep a nil in its position", function()
		local packed = table.pack(true, 1, nil, Vector3.new(1, 2, 3))

		expect(PlaytestRunner._serializeReturnValues(packed)).toEqual({
			1,
			{ type = "Nil" },
			{ type = "Vector3", value = { 1, 2, 3 } },
		})
	end)
end)
