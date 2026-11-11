--!strict
--[[
	@class CmdrReplyUtils.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local CmdrReplyUtils = require("CmdrReplyUtils")
local Jest = require("Jest")
local Promise = require("Promise")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local THRESHOLD = 0.05

local function setup()
	local replies: { { text: string, options: any } } = {}

	local context = {
		Reply = function(_self, text: string, options: any)
			table.insert(replies, { text = text, options = options })
		end,
	}

	return {
		config = CmdrReplyUtils.createConfig({ slowReplySeconds = THRESHOLD }),
		context = context :: any,
		replies = replies,
		waitPastThreshold = function()
			task.wait(THRESHOLD * 2)
		end,
	}
end

describe("CmdrReplyUtils.createConfig", function()
	it("fills in defaults", function()
		local config = CmdrReplyUtils.createConfig()

		expect(CmdrReplyUtils.isCmdrReplyConfig(config)).toEqual(true)
		expect(config.slowReplySeconds > 0).toEqual(true)
	end)

	it("keeps what it was given", function()
		local color = Color3.fromRGB(255, 0, 0)
		local config = CmdrReplyUtils.createConfig({ slowReplySeconds = 3, progressColor = color })

		expect(config.slowReplySeconds).toEqual(3)
		expect(config.progressColor).toEqual(color)
	end)

	it("rejects something that is not a config", function()
		expect(CmdrReplyUtils.isCmdrReplyConfig({ slowReplySeconds = 3 })).toEqual(false)
		expect(CmdrReplyUtils.isCmdrReplyConfig("nope")).toEqual(false)
	end)
end)

describe("CmdrReplyUtils.replyWhenSlow", function()
	it("hands back the promise it was given", function()
		local controller = setup()

		local promise = Promise.resolved("done")
		expect(CmdrReplyUtils.replyWhenSlow(controller.config, controller.context, promise, "still working...")).toBe(
			promise
		)
	end)

	it("says nothing when the work finishes first", function()
		local controller = setup()

		CmdrReplyUtils.replyWhenSlow(controller.config, controller.context, Promise.resolved("done"), "working...")
		controller.waitPastThreshold()

		expect(#controller.replies).toEqual(0)
	end)

	it("tells the executor when the work is still running", function()
		local controller = setup()

		local work = Promise.new()
		CmdrReplyUtils.replyWhenSlow(controller.config, controller.context, work, "working...")
		controller.waitPastThreshold()

		expect(#controller.replies).toEqual(1)
		expect(controller.replies[1].text).toEqual("working...")
		expect(controller.replies[1].options).toEqual(controller.config.progressColor)

		work:Resolve()
	end)

	it("says nothing more once the work lands", function()
		local controller = setup()

		local work = Promise.new()
		CmdrReplyUtils.replyWhenSlow(controller.config, controller.context, work, "working...")
		controller.waitPastThreshold()
		work:Resolve()
		controller.waitPastThreshold()

		expect(#controller.replies).toEqual(1)
	end)

	-- The reply is attached with Finally(), which resolves its own derived promise on a rejection. A
	-- caller handed that promise back would read every failure as a success.
	it("leaves a rejection to the caller", function()
		local controller = setup()

		local caught = nil
		CmdrReplyUtils.replyWhenSlow(controller.config, controller.context, Promise.rejected("nope"), "working...")
			:Catch(function(err)
				caught = err
			end)

		expect(caught).toEqual("nope")
	end)
end)
