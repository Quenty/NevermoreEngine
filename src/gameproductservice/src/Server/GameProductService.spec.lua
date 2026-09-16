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

	Server-side verification of a client's gamepass purchase claim is gated on server-only prompting
	(see [GameProductService.SetServerOnlyPromptingEnabled]), so it is covered from both sides: with
	the flag off the server takes the client's word, and with it on an unconfirmed claim grants
	nothing while a confirmed one grants the pass.

	@class GameProductService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameProductService = require("GameProductService")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
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

	local serverBag = ServiceBag.new()
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

	local clientBag = ServiceBag.new()
	clientBag:GetService(require("TieRealmService") :: any):SetTieRealm(require("TieRealms").CLIENT)
	local gameProductServiceClient: any = clientBag:GetService((require :: any)("GameProductServiceClient"))
	local playerMockServiceClient = clientBag:GetService((require :: any)("PlayerMockServiceClient"))
	clientBag:Init()

	local playerMock = playerMockService:CreatePlayer({ UserId = MOCK_USER_ID })
	playerMockServiceClient:SetLocalPlayer(playerMock)
	clientBag:Start()

	local controller = {
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
		Destroy = function(_self)
			clientBag:Destroy()
			serverBag:Destroy()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("GameProductService dual-realm boot", function()
	it("boots both the server and client product graphs", function()
		local controller = setup()

		expect(controller.gameProductService).never.toBeNil()
		expect(controller.gameProductServiceClient).never.toBeNil()

		controller:Destroy()
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

		controller:Destroy()
	end)
end)

describe("GameProductService server ownership from an injected lookup", function()
	it("resolves false for an uninjected gamepass and true for an injected one", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

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

		controller:Destroy()
	end)

	it("resolves ownership queried by a configured asset key", function()
		local controller = setup()
		controller.gameConfigService:AddPass("test_pass", GAME_PASS_ID)
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					"test_pass"
				)
			)
		).toEqual(true)

		controller:Destroy()
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

		controller:Destroy()
	end)
end)

describe("GameProductService ownership override", function()
	it("wins over the injected cloud answer", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

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

		controller:Destroy()
	end)

	it("clears back to the injected cloud answer", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

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

		controller:Destroy()
	end)
end)

describe("GameProductServiceClient ownership for the designated mock", function()
	it("resolves the same injected ownership as the server realm", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

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

		controller:Destroy()
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

		controller:Destroy()
	end)
end)

describe("client-initiated gamepass prompt", function()
	it("grants server ownership once the marketplace confirms the client's purchase", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.PromptGamePassPurchase", true, GAME_PASS_ID)

		local serverFired = {}
		local clientFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
		end)
		-- The pass is not owned when the prompt opens, so the client genuinely prompts. Model the
		-- purchase going through by marking the marketplace as owning it the instant the client reports
		-- success -- the same false-before / true-after transition a real purchase produces, and what
		-- the server's verification then reads.
		controller.gameProductServiceClient.GamePassPurchased:Connect(function(gamePassId)
			table.insert(clientFired, gamePassId)
			PlayerMock.writeLookup(
				controller.playerMock,
				"MarketplaceService.UserOwnsGamePassAsync",
				true,
				GAME_PASS_ID
			)
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

		controller:Destroy()
	end)

	it("takes the client's word for a purchase the marketplace never confirms", function()
		local controller = setup()
		-- Server-only prompting is off (the default), so the server has not been asked to establish
		-- purchases itself and grants on the client's report. This is a known trust gap, kept because
		-- verifying here would read UserOwnsGamePassAsync's per-server cache, which can still answer
		-- `false` for a purchase that just completed and would lose a pass the player paid for. Games
		-- that want the claim checked enable server-only prompting; see the verification describe below.
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.PromptGamePassPurchase", true, GAME_PASS_ID)

		local serverFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
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
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(true)

		controller:Destroy()
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

		controller:Destroy()
	end)
end)

describe("gamepass purchase verification under server-only prompting", function()
	-- With server-only prompting enabled the client may no longer prompt, so these drive the client's
	-- prompt-finished handler directly. That is the same entry point the engine's
	-- PromptGamePassPurchaseFinished reaches, and the one an exploiter reaches by firing the remote
	-- themselves -- which is exactly the claim under test.
	local function claimPurchaseFromClient(controller: any, gamePassId: number)
		local clientBinder = controller.clientBag:GetService((require :: any)("PlayerProductManagerClient"))

		PromiseTestUtils.awaitValue(function()
			return clientBinder:Get(controller.playerMock) ~= nil
		end, 10)

		local manager: any = clientBinder:Get(controller.playerMock)
		manager:_handleGamePassPromptFinished(gamePassId, true)
	end

	it("grants nothing for a claim the marketplace does not confirm", function()
		local controller = setup()
		controller.gameProductService:SetServerOnlyPromptingEnabled(true)

		-- UserOwnsGamePassAsync stays at its false default: the player never bought this pass. Any
		-- client can fire this remote for any gamepass id, so on its own the claim must grant nothing.
		local serverFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
		end)

		claimPurchaseFromClient(controller, GAME_PASS_ID)

		-- Awaiting the ownership query also lets the server's verification settle first.
		expect(
			controller.awaitBool(
				controller.gameProductService:PromisePlayerOwnership(
					controller.playerMock,
					GameConfigAssetTypes.PASS,
					GAME_PASS_ID
				)
			)
		).toEqual(false)
		expect(#serverFired).toEqual(0)
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(false)

		controller:Destroy()
	end)

	it("grants the pass for a claim the marketplace confirms", function()
		local controller = setup()
		controller.gameProductService:SetServerOnlyPromptingEnabled(true)

		-- The marketplace shows the player owning the pass, as it would after a real purchase.
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.UserOwnsGamePassAsync", true, GAME_PASS_ID)

		local serverFired = {}
		controller.gameProductService.GamePassPurchased:Connect(function(player, gamePassId)
			table.insert(serverFired, { player = player, gamePassId = gamePassId })
		end)

		claimPurchaseFromClient(controller, GAME_PASS_ID)

		PromiseTestUtils.awaitValue(function()
			return #serverFired > 0
		end, 10)

		expect(#serverFired).toEqual(1)
		expect(serverFired[1].player).toBe(controller.playerMock)
		expect(serverFired[1].gamePassId).toEqual(GAME_PASS_ID)
		expect(
			controller.gameProductService:HasPlayerPurchasedThisSession(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			)
		).toEqual(true)

		controller:Destroy()
	end)

	it("still refuses a client-initiated prompt", function()
		local controller = setup()
		controller.gameProductService:SetServerOnlyPromptingEnabled(true)

		-- Verification and the prompting restriction ship together: a game cannot take one without
		-- the other, so this records what enabling the flag costs the client realm.
		local outcome = PromiseTestUtils.awaitOutcome(
			controller.gameProductServiceClient:PromisePromptPurchase(
				controller.playerMock,
				GameConfigAssetTypes.PASS,
				GAME_PASS_ID
			),
			10
		)
		expect(outcome).toEqual("rejected")

		controller:Destroy()
	end)
end)

describe("server-initiated gamepass prompt", function()
	it("resolves true on accept and marks the session purchase", function()
		local controller = setup()
		PlayerMock.writeLookup(controller.playerMock, "MarketplaceService.PromptGamePassPurchase", true, GAME_PASS_ID)

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

		controller:Destroy()
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

		controller:Destroy()
	end)
end)
