--!strict
--[[
	Integration coverage for RagdollServiceClient booted headless against a pre-designated mock
	local player (designation must precede Init -- production parity, where Players.LocalPlayer
	exists before any service runs). Client binders never auto-tag, so the rigging test drives the
	same tags the server would replicate.

	@class RagdollServiceClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local RagdollClient = require("RagdollClient")
local RagdollServiceClient = require("RagdollServiceClient")
local RagdollTestUtils = require("RagdollTestUtils")
local RagdollableClient = require("RagdollableClient")
local RigBuilderUtils = require("RigBuilderUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0

local function setup()
	specCounter += 1

	local maid = Maid.new()
	JestUtils.afterThis(maid)

	local mock = PlayerMock.new({ UserId = 66123100 + specCounter })
	mock.Parent = Workspace
	maid:Add(PlayerMock.setMockedLocalPlayer(mock))

	local serviceBag = ServiceBag.new()
	local ragdollServiceClient = (
		serviceBag:GetService(RagdollServiceClient) :: any
	) :: RagdollServiceClient.RagdollServiceClient

	serviceBag:Init()
	serviceBag:Start()

	maid:GiveTask(function()
		serviceBag:Destroy()
		mock:Destroy()
	end)

	return {
		mock = mock,
		serviceBag = serviceBag,
		ragdollServiceClient = ragdollServiceClient,
	}
end

describe("RagdollServiceClient with a mocked local player", function()
	it("initializes, starts, and defaults screen shake to enabled", function()
		local state = setup()

		expect(state.ragdollServiceClient:GetScreenShakeEnabled()).toBe(true)
	end)

	it("writes screen shake changes to the local player attribute", function()
		local state = setup()

		state.ragdollServiceClient:SetScreenShakeEnabled(false)
		expect(state.ragdollServiceClient:GetScreenShakeEnabled()).toBe(false)
		expect(state.mock:GetAttribute("RagdollScreenShakeEnabled")).toBe(false)

		state.ragdollServiceClient:SetScreenShakeEnabled(true)
		expect(state.mock:GetAttribute("RagdollScreenShakeEnabled")).toBe(true)
	end)

	it("survives a character load while running", function()
		local state = setup()

		local character = RigBuilderUtils.createR6BaseRig()
		PlayerMock.loadCharacterAsync(state.mock, character)

		expect(character.Parent).toBe(Workspace)
		expect(character:FindFirstChildOfClass("Humanoid")).toBeDefined()
	end)

	it("rigs and unrigs the character through the client binders", function()
		local state = setup()

		local character = RigBuilderUtils.createR6BaseRig()
		PlayerMock.loadCharacterAsync(state.mock, character)
		local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "No humanoid in rig")

		local ragdollableBinder = state.serviceBag:GetService(RagdollableClient)
		local ragdollBinder = state.serviceBag:GetService(RagdollClient)

		ragdollableBinder:Bind(humanoid)
		PromiseTestUtils.awaitFulfilled(ragdollableBinder:Promise(humanoid))

		ragdollBinder:Bind(humanoid)
		expect(RagdollTestUtils.areMotorsEnabled(character, false)).toBe(true)

		ragdollBinder:Unbind(humanoid)
		expect(RagdollTestUtils.areMotorsEnabled(character, true)).toBe(true)
	end)
end)
