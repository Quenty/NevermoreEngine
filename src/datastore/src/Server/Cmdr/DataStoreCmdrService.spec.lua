--!strict
--[[
	Drives the command bodies directly. The service is built by hand rather than through a ServiceBag
	so the real CmdrService (and the Cmdr instance tree behind it) stays out of the test place --
	what is worth checking here is what the commands say and what they write, not Cmdr's plumbing.

	Command bodies take the userId list Cmdr's `playerIds` type parses, so these pass one directly.

	@class DataStoreCmdrService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local CmdrReplyUtils = require("CmdrReplyUtils")
local DataStoreCmdrService = require("DataStoreCmdrService")
local DataStoreTestUtils = require("DataStoreTestUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Promise = require("Promise")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Short enough that the progress tests do not have to sit through the real threshold.
local SLOW_REPLY_SECONDS = 0.05

local FOREIGN_LOCK = {
	LastUpdateTime = os.time(),
	ActiveSession = {
		SessionId = "foreign-session",
		PlaceId = 123,
		JobId = "foreign-job",
	},
}

local function setup()
	local controller = DataStoreTestUtils.setupDataStoreManager()

	local registered = {}
	local registeredTypes = {}
	local cmdr = {
		Registry = {
			RegisterType = function(_self, name, definition)
				registeredTypes[name] = definition
			end,
		},
	}
	local cmdrService = {
		RegisterCommand = function(_self, definition, execute)
			-- CmdrService ships the definition to the client as JSON, so a definition it cannot encode
			-- fails in-game at registration. Encode it here, where the failure is a test result.
			HttpService:JSONEncode(definition)
			registered[definition.Name] = execute
		end,
		PromiseCmdr = function()
			return Promise.resolved(cmdr)
		end,
	}

	local replies: { string } = {}
	local context = {
		Reply = function(_self, text: string)
			table.insert(replies, text)
		end,
	}

	local serviceMaid = Maid.new()
	local service = setmetatable({
		_maid = serviceMaid,
		_cmdrService = cmdrService,
		_playerDataStoreService = {
			PromiseManager = function()
				return Promise.resolved(controller.manager)
			end,
		},
	}, { __index = DataStoreCmdrService }) :: any

	service:SetReplyConfig(CmdrReplyUtils.createConfig({ slowReplySeconds = SLOW_REPLY_SECONDS }))
	service:Start()

	local cmdrController = {
		manager = controller.manager,
		mock = controller.mock,
		storeAndAwaitLock = controller.storeAndAwaitLock,
		subStoreType = function()
			return registeredTypes.dataStoreSubStore
		end,
		run = function(commandName: string, ...)
			return registered[commandName](context, ...)
		end,
		replies = replies,
		registeredNames = function()
			local names = {}
			for name, _ in registered do
				table.insert(names, name)
			end
			table.sort(names)
			return names
		end,
		destroy = function(_self)
			serviceMaid:DoCleaning()
			controller:destroy()
		end,
	}

	serviceMaid:GiveTask(JestUtils.afterThis(cmdrController.destroy))

	return cmdrController
end

describe("DataStoreCmdrService registration", function()
	it("registers the lock and data commands", function()
		local controller = setup()

		expect(controller.registeredNames()).toEqual({
			"datastore-copy",
			"datastore-delete",
			"datastore-lock",
			"datastore-lock-info",
			"datastore-read-json",
			"datastore-unlock",
			"datastore-write-json",
		})

		controller:destroy()
	end)

	it("registers the sub-store type", function()
		local controller = setup()

		expect(controller.subStoreType()).never.toBeNil()

		controller:destroy()
	end)

	it("takes players in bulk", function()
		local controller = setup()

		expect(controller.run("datastore-lock-info", {})).toEqual("No players to act on.")

		controller:destroy()
	end)

	it("stays quiet while a command is quick", function()
		local controller = setup()

		controller.run("datastore-lock-info", { 1 })
		task.wait(SLOW_REPLY_SECONDS * 2)

		expect(#controller.replies).toEqual(0)

		controller:destroy()
	end)

	it("reports a target that is taking a while", function()
		local controller = setup()

		controller.mock:SetYieldTime(SLOW_REPLY_SECONDS * 2)

		controller.run("datastore-lock-info", { 1 })

		expect(#controller.replies).toEqual(1)
		expect(string.find(controller.replies[1], "1: ", 1, true) ~= nil).toEqual(true)

		controller:destroy()
	end)
end)

describe("datastore-lock-info", function()
	it("reports an unlocked key", function()
		local controller = setup()

		expect(string.find(controller.run("datastore-lock-info", { 1 }), "unlocked") ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("names the session holding the lock", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, lock = FOREIGN_LOCK })

		expect(string.find(controller.run("datastore-lock-info", { 1 }), "foreign%-job") ~= nil).toEqual(true)

		controller:destroy()
	end)

	it("reports every target on its own line", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, lock = FOREIGN_LOCK })
		controller.mock:SetRaw("user_2", { coins = 5 })

		local output = controller.run("datastore-lock-info", { 1, 2 })
		expect(string.find(output, "1: ") ~= nil).toEqual(true)
		expect(string.find(output, "2: ") ~= nil).toEqual(true)

		controller:destroy()
	end)
end)

describe("datastore-unlock", function()
	it("clears a foreign lock", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, lock = FOREIGN_LOCK })

		local output = controller.run("datastore-unlock", { 1 })
		expect(string.find(output, "Unlocked") ~= nil).toEqual(true)
		expect(controller.mock:GetRaw("user_1").lock).toBeNil()
		expect(controller.mock:GetRaw("user_1").coins).toEqual(5)

		controller:destroy()
	end)

	it("says so when there was nothing to clear", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5 })

		expect(string.find(controller.run("datastore-unlock", { 1 }), "already unlocked") ~= nil).toEqual(true)

		controller:destroy()
	end)

	-- These are stress-test tools, so a live local session is a target rather than a refusal.
	it("clears a key this server holds a live session for", function()
		local controller = setup()

		if not controller.storeAndAwaitLock() then
			expect("lock was never acquired").toEqual("lock was acquired")
			controller:destroy()
			return
		end

		expect(string.find(controller.run("datastore-unlock", { 1 }), "Unlocked") ~= nil).toEqual(true)
		expect(controller.mock:GetRaw("user_1").lock).toBeNil()

		controller:destroy()
	end)

	it("clears every target in a batch", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, lock = FOREIGN_LOCK })
		controller.mock:SetRaw("user_2", { coins = 5, lock = FOREIGN_LOCK })

		local output = controller.run("datastore-unlock", { 1, 2 })
		expect(string.find(output, "Unlocked 1") ~= nil).toEqual(true)
		expect(string.find(output, "Unlocked 2") ~= nil).toEqual(true)
		expect(controller.mock:GetRaw("user_1").lock).toBeNil()
		expect(controller.mock:GetRaw("user_2").lock).toBeNil()

		controller:destroy()
	end)
end)

describe("datastore-lock", function()
	it("claims an unlocked key", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5 })

		expect(string.find(controller.run("datastore-lock", { 1 }), "Locked") ~= nil).toEqual(true)
		expect(controller.mock:GetRaw("user_1").lock).never.toBeNil()

		controller:destroy()
	end)

	it("reports the lock it replaced", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, lock = FOREIGN_LOCK })

		expect(string.find(controller.run("datastore-lock", { 1 }), "foreign%-job") ~= nil).toEqual(true)

		controller:destroy()
	end)
end)

-- The data commands scope to a sub-store rather than the root wherever they can, so a write under
-- test cannot clobber the session lock the manager is keeping on the same key.
describe("datastore-read-json", function()
	it("reads the stored data back as JSON", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { profile = { level = 7 } })

		local output = controller.run("datastore-read-json", { 1 }, { "profile" })
		expect(string.find(output, '"level"') ~= nil).toEqual(true)
		expect(string.find(output, "7") ~= nil).toEqual(true)

		controller:destroy()
	end)
end)

describe("datastore-write-json", function()
	it("writes a sub-store", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5 })

		controller.run("datastore-write-json", { 1 }, '{"level":7}', { "profile" })
		expect(controller.mock:GetRaw("user_1").profile.level).toEqual(7)
		expect(controller.mock:GetRaw("user_1").coins).toEqual(5)

		controller:destroy()
	end)

	it("reports undecodable JSON as a failure", function()
		local controller = setup()

		expect(string.find(controller.run("datastore-write-json", { 1 }, "not json", nil), "Failed") ~= nil).toEqual(
			true
		)

		controller:destroy()
	end)
end)

describe("datastore-delete", function()
	it("wipes a sub-store and leaves the rest of the key", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { coins = 5, profile = { level = 7 } })

		controller.run("datastore-delete", { 1 }, { "profile" })
		expect(controller.mock:GetRaw("user_1").profile).toBeNil()
		expect(controller.mock:GetRaw("user_1").coins).toEqual(5)

		controller:destroy()
	end)
end)

describe("datastore-copy", function()
	it("copies a sub-store onto another player", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { profile = { level = 7 } })
		controller.mock:SetRaw("user_2", { profile = { level = 1 } })

		controller.run("datastore-copy", 1, { 2 }, { "profile" })
		expect(controller.mock:GetRaw("user_2").profile.level).toEqual(7)

		controller:destroy()
	end)

	it("copies onto an absent player through a store that yields", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { profile = { level = 7 } })
		controller.mock:SetRaw("user_2", { profile = { level = 1 } })
		controller.mock:SetYieldTime(0.05)

		controller.run("datastore-copy", 1, { 2 }, { "profile" })

		expect(controller.mock:GetRaw("user_2").profile.level).toEqual(7)

		controller:destroy()
	end)

	it("skips the source when it is also a target", function()
		local controller = setup()

		controller.mock:SetRaw("user_1", { profile = { level = 7 } })

		local output = controller.run("datastore-copy", 1, { 1 }, { "profile" })
		expect(string.find(output, "Skipped") ~= nil).toEqual(true)

		controller:destroy()
	end)
end)
