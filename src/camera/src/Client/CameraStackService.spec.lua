--!strict
--[[
	@class CameraStackService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local CameraStackService = require("CameraStackService")
local CameraState = require("CameraState")
local CustomCameraEffect = require("CustomCameraEffect")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(options: { start: boolean? }?): CameraStackService.CameraStackService
	local maid = Maid.new()
	JestUtils.afterThis(maid)

	local player = PlayerMock.new({ UserId = 66123201 })
	player.Parent = Workspace
	local restoreLocalPlayer = PlayerMock.setMockedLocalPlayer(player)

	local serviceBag = ServiceBag.new()
	local service: CameraStackService.CameraStackService = serviceBag:GetService(CameraStackService) :: any
	serviceBag:Init()

	if not (options and options.start == false) then
		serviceBag:Start()
	end

	maid:GiveTask(function()
		serviceBag:Destroy()
		restoreLocalPlayer()
		player:Destroy()
	end)

	return service
end

local function makeEffect(): (CustomCameraEffect.CustomCameraEffect, CameraState.CameraState)
	local state = CameraState.new()
	local effect = CustomCameraEffect.new(function()
		return state
	end)
	return effect, state
end

describe("CameraStackService.Init", function()
	it("initializes with the default camera at the bottom of the stack", function()
		local service = setup()

		expect(#service:GetRawStack()).toBe(1)
		expect(service:GetIndex(service:GetDefaultCamera())).toBe(1)
		expect(service:GetTopCamera()).toBe(service:GetDefaultCamera())
		expect(CameraState.isCameraState(service:GetTopState())).toBe(true)
	end)

	it("exposes the default, raw default, and impulse cameras", function()
		local service = setup()

		expect(service:GetDefaultCamera()).toBe(service:GetDefaultCamera())
		expect(service:GetRawDefaultCamera()).toBe(service:GetRawDefaultCamera())
		expect(service:GetImpulseCamera()).toBe(service:GetImpulseCamera())
	end)

	it("errors when used before the service bag runs Init", function()
		local serviceBag = ServiceBag.new()
		JestUtils.afterThis(serviceBag)
		local service: CameraStackService.CameraStackService = serviceBag:GetService(CameraStackService) :: any

		expect(function()
			service:GetTopState()
		end).toThrow("Not initialized")

		-- Destroying a never-initialized CameraStackService errors on its nil maid, so finish
		-- initialization for teardown.
		serviceBag:Init()
	end)
end)

describe("CameraStackService.Add", function()
	it("puts the effect on top of the stack and surfaces its state", function()
		local service = setup()
		local effect, state = makeEffect()

		service:Add(effect)

		expect(service:GetIndex(effect)).toBe(2)
		expect(service:GetTopCamera()).toBe(effect)
		expect(service:GetTopState()).toBe(state)
	end)

	it("returns a cleanup callback that removes the effect", function()
		local service = setup()
		local effect = makeEffect()

		local removeEffect = service:Add(effect)
		expect(service:GetIndex(effect)).toBe(2)

		removeEffect()
		expect(service:GetIndex(effect)).toBeNil()
		expect(service:GetTopCamera()).toBe(service:GetDefaultCamera())
	end)
end)

describe("CameraStackService.Remove", function()
	it("removes the effect from anywhere in the stack", function()
		local service = setup()
		local effectA = makeEffect()
		local effectB = makeEffect()

		service:Add(effectA)
		service:Add(effectB)

		service:Remove(effectA)

		expect(service:GetIndex(effectA)).toBeNil()
		expect(service:GetIndex(effectB)).toBe(2)
		expect(service:GetTopCamera()).toBe(effectB)
	end)
end)

describe("CameraStackService.PushDisable", function()
	it("hides the top state until cancelled", function()
		local service = setup()

		local cancel = service:PushDisable()
		expect(service:GetTopState()).toBeNil()

		cancel()
		expect(CameraState.isCameraState(service:GetTopState())).toBe(true)
	end)
end)

describe("CameraStackService.GetNewStateBelow", function()
	it("resolves to the state below the effect once added", function()
		local service = setup()
		local belowEffect, belowState = makeEffect()
		service:Add(belowEffect)

		local effect, setState = service:GetNewStateBelow()
		setState(effect)
		service:Add(effect)

		expect(service:GetIndex(effect)).toBe(3)
		expect((effect :: any).CameraState).toBe(belowState)
	end)
end)

describe("CameraStackService.SetDoNotUseDefaultCamera", function()
	it("can be set before the service starts", function()
		local service = setup({ start = false })

		expect(function()
			service:SetDoNotUseDefaultCamera(true)
		end).never.toThrow()
	end)

	it("errors once the service has started", function()
		local service = setup()

		expect(function()
			service:SetDoNotUseDefaultCamera(true)
		end).toThrow("Already started")
	end)
end)
