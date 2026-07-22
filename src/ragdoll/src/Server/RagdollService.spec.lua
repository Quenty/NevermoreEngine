--!strict
--[[
	Integration coverage for RagdollService booted the way production does -- through a ServiceBag
	-- against a PlayerMock whose character is a local R6 rig. Discovery flows mock join ->
	PlayerHumanoidBinder -> bind, so no test reaches in to Tag by hand; ragdolling drives the
	public Ragdoll binder.

	@class RagdollService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local Ragdoll = require("Ragdoll")
local RagdollHumanoidOnFall = require("RagdollHumanoidOnFall")
local RagdollHumanoidOnFallConstants = require("RagdollHumanoidOnFallConstants")
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

	local container = Instance.new("Folder")
	container.Name = string.format("RagdollServiceSpecContainer_%d", specCounter)
	container.Parent = Workspace

	local serviceBag = ServiceBag.new()
	local ragdollService: any = serviceBag:GetService(RagdollService)
	local playerMockService = serviceBag:GetService(PlayerMockService)

	serviceBag:Init()
	serviceBag:Start()

	local mock = playerMockService:CreatePlayer({ UserId = 66123200 + specCounter })
	mock.Parent = container

	local character = RigBuilderUtils.createR6BaseRig()
	PlayerMock.loadCharacterAsync(mock, character)

	local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "No humanoid in rig")

	local bagDestroyed = false
	local function destroyBag()
		if not bagDestroyed then
			bagDestroyed = true
			serviceBag:Destroy()
		end
	end

	local function destroy()
		destroyBag()
		mock:Destroy()
		container:Destroy()
	end

	return {
		serviceBag = serviceBag,
		ragdollService = ragdollService,
		mock = mock,
		character = character,
		humanoid = humanoid,
		destroyBag = destroyBag,
		destroy = destroy,
	}
end

describe("RagdollService with a mock player R6 character", function()
	it("binds Ragdollable through mock discovery and pre-rigs ball sockets", function()
		local state = setup()

		local ragdollableBinder = state.serviceBag:GetService(Ragdollable)
		local ok = ragdollableBinder:Promise(state.humanoid):Yield()
		assert(ok, "Ragdollable never bound")

		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.countBallSockets(state.character) == 5
		end)).toBe(true)

		local torso = assert(state.character:FindFirstChild("Torso"), "No torso")
		expect(torso:FindFirstChild("NeckAttachment")).toBeDefined()
		expect(torso:FindFirstChild("LeftShoulderRagdollAttachment")).toBeDefined()

		state.destroy()
	end)

	it("suppresses motors while Ragdoll is bound and restores them on unbind", function()
		local state = setup()

		local ragdollableBinder = state.serviceBag:GetService(Ragdollable)
		local ok = ragdollableBinder:Promise(state.humanoid):Yield()
		assert(ok, "Ragdollable never bound")

		local ragdollBinder = state.serviceBag:GetService(Ragdoll)
		expect(RagdollTestUtils.areMotorsEnabled(state.character, true)).toBe(true)

		ragdollBinder:Bind(state.humanoid)
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(state.character, false)
		end)).toBe(true)
		expect(ragdollBinder:Get(state.humanoid)).toBeDefined()

		ragdollBinder:Unbind(state.humanoid)
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(state.character, true)
		end)).toBe(true)
		expect(ragdollBinder:Get(state.humanoid)).toBeNil()

		state.destroy()
	end)

	it("tears down while ragdolled, despawning the mock character", function()
		local state = setup()

		local ragdollableBinder = state.serviceBag:GetService(Ragdollable)
		local ok = ragdollableBinder:Promise(state.humanoid):Yield()
		assert(ok, "Ragdollable never bound")

		state.serviceBag:GetService(Ragdoll):Bind(state.humanoid)
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(state.character, false)
		end)).toBe(true)

		state.destroyBag()

		-- The bag's PlayerMockService owns the mock, so teardown despawns the character with it.
		expect(RagdollTestUtils.waitFor(function()
			return state.character.Parent == nil
		end)).toBe(true)

		state.destroy()
	end)

	it("SetRagdollOnFall toggles automatic tagging and the fall remote event", function()
		local state = setup()

		local onFallBinder = state.serviceBag:GetService(RagdollHumanoidOnFall)
		expect(onFallBinder:Get(state.humanoid)).toBeNil()

		state.ragdollService:SetRagdollOnFall(true)

		local ok = onFallBinder:Promise(state.humanoid):Yield()
		assert(ok, "RagdollHumanoidOnFall never bound")
		expect(state.humanoid:FindFirstChild(RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME)).toBeDefined()

		state.ragdollService:SetRagdollOnFall(false)
		RagdollTestUtils.awaitUnbound(onFallBinder, state.humanoid)

		expect(onFallBinder:Get(state.humanoid)).toBeNil()
		expect(state.humanoid:FindFirstChild(RagdollHumanoidOnFallConstants.REMOTE_EVENT_NAME)).toBeNil()

		state.destroy()
	end)
end)
