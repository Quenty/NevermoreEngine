--!strict
--[[
	Dual-realm integration coverage for GameProductService. Boots a SERVER and a CLIENT ServiceBag
	in the same DataModel (mirroring TelemetryServicePlayerFlow.spec) and drives ownership
	end-to-end against a PlayerMock: PlayerBinder discovery, gamepass ownership resolved on both
	realms from the ownership injected on the mock via PlayerMock.writeLookup
	("MarketplaceService.UserOwnsGamePassAsync"), config-key resolution through GameConfigService,
	and the server-authoritative ownership override winning over the injected cloud answer.

	Prompting is covered end-to-end from both realms: the injected
	"MarketplaceService.PromptGamePassPurchase" decision answers the prompt the engine cannot show
	a mock, and a client-initiated accept replicates to the server over the production remoting
	path (session purchase, ownership, and both realms' purchase signals).

	@class GameProductService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameProductService = require("GameProductService")
local Jest = require("Jest")
local Maid = require("Maid")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")
local StepUtils = require("StepUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MOCK_USER_ID = 55234567
local GAME_PASS_ID = 111222333
local OTHER_GAME_PASS_ID = 444555666

local remoteNameCounter = 0

local function setup()
	local maid = Maid.new()

	local serverBag = maid:Add(ServiceBag.new())
	serverBag:GetService(require("TieRealmService") :: any):SetTieRealm(require("TieRealms").SERVER)

	local gameProductService: any = serverBag:GetService(GameProductService)
	local gameConfigService = serverBag:GetService(require("GameConfigService") :: any)
	local playerMockService = serverBag:GetService(require("PlayerMockService") :: any)
	local permissionService = serverBag:GetService(require("PermissionService") :: any)
	serverBag:Init()

	remoteNameCounter += 1
	permissionService:SetProviderFromConfig(PermissionProviderUtils.createSingleUserConfig({
		userId = MOCK_USER_ID,
		remoteFunctionName = string.format("GameProductServiceSpecPermissionRemote%d", remoteNameCounter),
	}))
	serverBag:Start()

	local clientBag = maid:Add(ServiceBag.new())
	clientBag:GetService(require("TieRealmService") :: any):SetTieRealm(require("TieRealms").CLIENT)
	local gameProductServiceClient: any = clientBag:GetService((require :: any)("GameProductServiceClient"))
	local playerMockServiceClient = clientBag:GetService((require :: any)("PlayerMockServiceClient"))
	clientBag:Init()

	local playerMock = playerMockService:CreatePlayer({ UserId = MOCK_USER_ID })
	playerMockServiceClient:SetLocalPlayer(playerMock)
	clientBag:Start()

	return {
		serverBag = serverBag,
		clientBag = clientBag,
		gameProductService = gameProductService,
		gameProductServiceClient = gameProductServiceClient,
		gameConfigService = gameConfigService,
		playerMock = playerMock,
		awaitBool = function(promise: any): boolean
			expect(PromiseTestUtils.awaitSettled(promise, 10)).toEqual(true)
			local ok, value = promise:Yield()
			expect(ok).toEqual(true)
			return value
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("GameProductService dual-realm boot", function()
	it("boots both the server and client product graphs", function()
		local controller = setup()

		expect(controller.gameProductService).never.toBeNil()
		expect(controller.gameProductServiceClient).never.toBeNil()

		controller:destroy()
	end)
end)

describe("PlayerProductManager discovers a PlayerMock", function()
	it("binds PlayerProductManager to a PlayerMock without a manual Bind", function()
		local controller = setup()
		local binder = controller.serverBag:GetService((require :: any)("PlayerProductManager"))

		PromiseTestUtils.awaitValue(function()
			return binder:Get(controller.playerMock) ~= nil
		end, 10)

		expect(binder:Get(controller.playerMock)).never.toBeNil()

		controller:destroy()
	end)
end)

describe("GameProductService server ownership from an injected lookup", function()
	it("resolves false for an uninjected gamepass and true for an injected one", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					OTHER_GAME_PASS_ID
				)
			)
		).toEqual(false)
		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		controller:destroy()
	end)

	it("resolves ownership queried by a configured asset key", function()
		local controller = setup()
		controller.gameConfigService:AddPass("test_pass", GAME_PASS_ID)
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					"test_pass"
				)
			)
		).toEqual(true)

		controller:destroy()
	end)

	it("rejects an unconfigured asset key", function()
		local controller = setup()

		local outcome = PromiseTestUtils.awaitOutcome(
			controller.gameProductService:PromisePlayerOwnership(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				"never_configured_pass"
			),
			10
		)
		expect(outcome).toEqual("rejected")

		controller:destroy()
	end)
end)

describe("GameProductService ownership override", function()
	it("wins over the injected cloud answer", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		controller.awaitBool(
			controller.gameProductService:SetPlayerOwnershipOverride(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID,
				false
			) :: any
		)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(false)

		controller:destroy()
	end)

	it("clears back to the injected cloud answer", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		controller.awaitBool(
			controller.gameProductService:SetPlayerOwnershipOverride(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID,
				false
			) :: any
		)
		controller.awaitBool(
			controller.gameProductService:ClearPlayerOwnershipOverride(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			) :: any
		)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		controller:destroy()
	end)
end)

describe("GameProductServiceClient ownership for the designated mock", function()
	it("resolves the same injected ownership as the server realm", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)
		expect(
			controller.awaitBool(
				controller.gameProductServiceClient:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		controller:destroy()
	end)

	it("reports no session purchases for the mock on either realm", function()
		local controller = setup()

		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)
		expect(
			controller.gameProductServiceClient:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)

		controller:destroy()
	end)
end)

describe("client-initiated gamepass prompt", function()
	it("resolves true on accept, replicates to the server, and fires both realms' purchase signals", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.PromptGamePassPurchase", GAME_PASS_ID, true)

		local serverFired = {}
		local clientFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
		end)
		controller.gameProductServiceClient.GamePassPurchased:Connect(function(gamePassId)
			table.insert(clientFired, gamePassId)
		end)

		expect(
			controller.awaitBool(
				controller.gameProductServiceClient:PromisePromptPurchase(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		PromiseTestUtils.awaitValue(function()
			return #serverFired > 0
		end, 10)

		expect(#serverFired).toEqual(1)
		expect(serverFired[1].player).toBe(controller.playerMock)
		expect(serverFired[1].gamePassId).toEqual(GAME_PASS_ID)
		expect(clientFired[1]).toEqual(GAME_PASS_ID)
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(true)
		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		controller:destroy()
	end)

	it("resolves false on reject and marks nothing purchased on either realm", function()
		local controller = setup()

		local serverFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function()
			table.insert(serverFired, true)
		end)

		expect(
			controller.awaitBool(
				controller.gameProductServiceClient:PromisePromptPurchase(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(false)

		-- Resolving the prompt promise resumed this thread mid-handler; let the handler's
		-- remaining work (the decline forward to the server) run before tearing down.
		StepUtils.deferWait()

		expect(#serverFired).toEqual(0)
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)
		expect(
			controller.gameProductServiceClient:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)

		controller:destroy()
	end)
end)

describe("server-initiated gamepass prompt", function()
	it("resolves true on accept and marks the session purchase", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.PromptGamePassPurchase", GAME_PASS_ID, true)

		local serverFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
		end)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerPromptPurchase(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		PromiseTestUtils.awaitValue(function()
			return #serverFired > 0
		end, 10)

		expect(#serverFired).toEqual(1)
		expect(serverFired[1].gamePassId).toEqual(GAME_PASS_ID)
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(true)
		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(true)

		controller:destroy()
	end)

	it("resolves false on reject and leaves ownership untouched", function()
		local controller = setup()

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerPromptPurchase(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(false)

		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)
		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(false)

		controller:destroy()
	end)
end)
