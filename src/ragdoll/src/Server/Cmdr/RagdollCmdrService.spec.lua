--!strict
--[[
	Drives the command bodies against a mock player whose character is a local R6 rig. The service is
	built by hand around a fake CmdrService, since the real one needs the Cmdr instance tree and a
	running game -- what is worth checking here is that the commands move the public Ragdoll binder,
	and that a player list is handled a player at a time.

	Command bodies take the player array Cmdr's `players` type parses, so these pass one directly.

	@class RagdollCmdrService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local Promise = require("Promise")
local Ragdoll = require("Ragdoll")
local RagdollCmdrService = require("RagdollCmdrService")
local RagdollService = require("RagdollService")
local RagdollTestUtils = require("RagdollTestUtils")
local Ragdollable = require("Ragdollable")
local RigBuilderUtils = require("RigBuilderUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function setup()
	specCounter += 1

	local maid = Maid.new()

	local container = Instance.new("Folder")
	container.Name = string.format("RagdollCmdrServiceSpecContainer_%d", specCounter)
	container.Parent = Workspace
	maid:GiveTask(container)

	local serviceBag = maid:Add(ServiceBag.new())
	serviceBag:GetService(RagdollService)
	local playerMockService: any = serviceBag:GetService(PlayerMockService)

	serviceBag:Init()
	serviceBag:Start()

	local registered: { [string]: (any, ...any) -> string } = {}
	local cmdrService = {
		RegisterCommand = function(_self, definition, execute)
			registered[definition.Name] = execute
		end,
		PromiseCmdr = function()
			return Promise.resolved({})
		end,
	}

	-- Typed loosely: the fields are filled in by hand rather than by Init, so the table is not a
	-- RagdollCmdrService until the last of them lands.
	local service: any = setmetatable({}, { __index = RagdollCmdrService })
	service._maid = Maid.new()
	service._serviceBag = serviceBag
	service._cmdrService = cmdrService
	service._ragdollBinder = serviceBag:GetService(Ragdoll)
	service:Start()

	maid:GiveTask(function()
		service:Destroy()
	end)

	local ragdollableBinder = serviceBag:GetService(Ragdollable)
	local mockCounter = 0

	local function addPlayer()
		mockCounter += 1

		local mock = playerMockService:CreatePlayer({ UserId = 66223300 + specCounter * 10 + mockCounter })
		mock.Parent = container
		maid:GiveTask(mock)

		local character = RigBuilderUtils.createR6BaseRig()
		PlayerMock.loadCharacterAsync(mock, character)

		local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "No humanoid in rig")

		-- Ragdolling only reaches the motors once Ragdollable has rigged the character, which mock
		-- discovery does on its own a moment after the character loads.
		local ok = ragdollableBinder:Promise(humanoid):Yield()
		assert(ok, "Ragdollable never bound")

		return {
			mock = mock,
			character = character,
			humanoid = humanoid,
		}
	end

	local controller = {
		serviceBag = serviceBag,
		ragdollBinder = serviceBag:GetService(Ragdoll),
		addPlayer = addPlayer,
		run = function(commandName: string, ...)
			return registered[commandName]({}, ...)
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("RagdollCmdrService", function()
	it("ragdolls and unragdolls a player, suppressing and restoring their motors", function()
		local controller = setup()
		local player = controller.addPlayer()

		local output = controller.run("ragdoll", { player.mock })
		expect(string.find(output, "Ragdolled", 1, true) ~= nil).toEqual(true)
		expect(controller.ragdollBinder:Get(player.humanoid)).toBeDefined()
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(player.character, false)
		end)).toBe(true)

		output = controller.run("unragdoll", { player.mock })
		expect(string.find(output, "Unragdolled", 1, true) ~= nil).toEqual(true)
		expect(controller.ragdollBinder:Get(player.humanoid)).toBeNil()
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(player.character, true)
		end)).toBe(true)

		controller:Destroy()
	end)

	it("acts on every player in the list", function()
		local controller = setup()
		local first = controller.addPlayer()
		local second = controller.addPlayer()

		controller.run("ragdoll", { first.mock, second.mock })
		expect(controller.ragdollBinder:Get(first.humanoid)).toBeDefined()
		expect(controller.ragdollBinder:Get(second.humanoid)).toBeDefined()

		controller.run("unragdoll", { first.mock, second.mock })
		expect(controller.ragdollBinder:Get(first.humanoid)).toBeNil()
		expect(controller.ragdollBinder:Get(second.humanoid)).toBeNil()

		controller:Destroy()
	end)

	it("reports the players it could not act on without skipping the rest", function()
		local controller = setup()
		local ragdolled = controller.addPlayer()
		local characterless = controller.addPlayer()

		PlayerMock.removeCharacter(characterless.mock)

		local output = controller.run("ragdoll", { characterless.mock, ragdolled.mock })
		expect(string.find(output, "has no character", 1, true) ~= nil).toEqual(true)
		expect(controller.ragdollBinder:Get(ragdolled.humanoid)).toBeDefined()

		-- Already-ragdolled and not-ragdolled are reported rather than acted on twice.
		expect(string.find(controller.run("ragdoll", { ragdolled.mock }), "already ragdolled", 1, true) ~= nil).toEqual(
			true
		)
		expect(string.find(controller.run("unragdoll", { characterless.mock }), "has no character", 1, true) ~= nil).toEqual(
			true
		)

		controller.run("unragdoll", { ragdolled.mock })
		expect(string.find(controller.run("unragdoll", { ragdolled.mock }), "is not ragdolled", 1, true) ~= nil).toEqual(
			true
		)

		controller:Destroy()
	end)

	it("reports an empty player list", function()
		local controller = setup()

		expect(controller.run("ragdoll", {})).toEqual("No players to act on.")
		expect(controller.run("unragdoll", {})).toEqual("No players to act on.")

		controller:Destroy()
	end)
end)
