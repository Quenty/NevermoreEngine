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
local PlayerMock = require("PlayerMock")
local RagdollClient = require("RagdollClient")
local RagdollServiceClient = require("RagdollServiceClient")
local RagdollTestUtils = require("RagdollTestUtils")
local RagdollableClient = require("RagdollableClient")
local RigBuilderUtils = require("RigBuilderUtils")
local ServiceBag = require("ServiceBag")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local specCounter = 0
local currentMock: Player? = nil
local currentServiceBag: ServiceBag.ServiceBag? = nil

local function setup()
	specCounter += 1

	local mock = PlayerMock.new({ UserId = 66123100 + specCounter })
	mock.Parent = Workspace
	PlayerMock.setMockedLocalPlayer(mock)
	currentMock = mock

	local serviceBag = ServiceBag.new()
	local ragdollServiceClient = (
		serviceBag:GetService(RagdollServiceClient) :: any
	) :: RagdollServiceClient.RagdollServiceClient

	serviceBag:Init()
	serviceBag:Start()
	currentServiceBag = serviceBag

	return {
		mock = mock,
		serviceBag = serviceBag,
		ragdollServiceClient = ragdollServiceClient,
	}
end

afterEach(function()
	if currentServiceBag ~= nil then
		currentServiceBag:Destroy()
		currentServiceBag = nil
	end

	PlayerMock.setMockedLocalPlayer(nil)

	if currentMock ~= nil then
		currentMock:Destroy()
		currentMock = nil
	end
end)

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
		local ok = ragdollableBinder:Promise(humanoid):Yield()
		assert(ok, "RagdollableClient never bound")

		ragdollBinder:Bind(humanoid)
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(character, false)
		end)).toBe(true)

		ragdollBinder:Unbind(humanoid)
		expect(RagdollTestUtils.waitFor(function()
			return RagdollTestUtils.areMotorsEnabled(character, true)
		end)).toBe(true)
	end)
end)
