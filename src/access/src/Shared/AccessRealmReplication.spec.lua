--!strict
--[[
	@class AccessRealmReplication.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessPolicy = require("AccessPolicy")
local AccessPolicyRealm = require("AccessPolicyRealm")
local AccessPolicyService = require("AccessPolicyService")
local AccessService = require("AccessService")
local AccessServiceClient = require("AccessServiceClient")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local ObservableSpy = require("ObservableSpy")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FEATURE_FACT_NAMES_ATTRIBUTE = "AccessFeatureFactNames"

local featureCounter = 0
local playerCounter = 0
local policyCounter = 0

local function newRealmBag(tieRealm: string): ServiceBag.ServiceBag
	local serviceBag = ServiceBag.new();
	(serviceBag:GetService(TieRealmService) :: any):SetTieRealm(tieRealm)
	return serviceBag
end

type Controller = {
	maid: Maid.Maid,
	server: AccessDataService.AccessDataService,
	client: AccessDataService.AccessDataService,
	featureName: string,
	factName: string,
	registerFeature: (
		self: Controller,
		accessDataService: AccessDataService.AccessDataService,
		factNames: { string }
	) -> AccessFeature.AccessFeature,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()

	local serverBag = newRealmBag(TieRealms.SERVER)
	local server: AccessDataService.AccessDataService = serverBag:GetService(AccessDataService) :: any
	serverBag:Init()
	serverBag:Start()

	local clientBag = newRealmBag(TieRealms.CLIENT)
	local client: AccessDataService.AccessDataService = clientBag:GetService(AccessDataService) :: any
	clientBag:Init()
	clientBag:Start()

	maid:GiveTask(function()
		clientBag:Destroy()
		serverBag:Destroy()
	end)

	featureCounter += 1
	local featureName = `chapters{featureCounter}`

	local controller: Controller = {
		maid = maid,
		server = server,
		client = client,
		featureName = featureName,
		factName = `gamePass{featureCounter}`,
		registerFeature = function(_self, accessDataService, factNames)
			local feature = maid:Add(AccessFeature.anyOf(featureName, factNames))
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

type PlayersController = {
	maid: Maid.Maid,
	server: AccessDataService.AccessDataService,
	client: AccessDataService.AccessDataService,
	factName: string,
	player: Player,
	serverFact: (self: PlayersController, value: boolean?) -> ValueObject.ValueObject<boolean?>,
	sharedFact: (self: PlayersController, value: boolean?) -> ValueObject.ValueObject<boolean?>,
	clientFeature: (self: PlayersController) -> ObservableSpy.ObservableSpy<AccessStateUtils.AccessState>,
	Destroy: (self: PlayersController) -> (),
}

local function setupPlayers(): PlayersController
	local maid = Maid.new()

	local serverBag = newRealmBag(TieRealms.SERVER)
	local serverAccess: AccessDataService.AccessDataService = serverBag:GetService(AccessDataService) :: any
	serverBag:GetService(AccessService)
	serverBag:Init()
	serverBag:Start()

	local clientBag = newRealmBag(TieRealms.CLIENT)
	local clientAccess: AccessDataService.AccessDataService = clientBag:GetService(AccessDataService) :: any
	clientBag:GetService(AccessServiceClient)
	clientBag:Init()
	clientBag:Start()

	local playerMockService: any = serverBag:GetService(PlayerMockService)

	playerCounter += 1
	local factName = `serverOnly{playerCounter}`
	local player: Player = maid:Add(playerMockService:CreatePlayer())

	local function registerFact(
		accessDataService: AccessDataService.AccessDataService,
		value: boolean?,
		behavior: string?
	)
		local resolved = maid:Add(ValueObject.new(value))
		maid:GiveTask(accessDataService:RegisterFact(maid:Add(AccessFact.new(factName, {
			resolve = function()
				return resolved
			end,
			serverOverrideBehavior = behavior,
		}))))
		return resolved
	end

	local controller: PlayersController = {
		maid = maid,
		server = serverAccess,
		client = clientAccess,
		factName = factName,
		player = player,
		serverFact = function(_self, value)
			return registerFact(serverAccess, value, AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ALL)
		end,
		sharedFact = function(_self, value)
			local resolved = registerFact(clientAccess, value)
			maid:GiveTask(serverAccess:RegisterFact(maid:Add(AccessFact.new(factName, {
				resolve = function()
					return resolved
				end,
			}))))
			return resolved
		end,
		clientFeature = function(_self)
			local feature = maid:Add(AccessFeature.anyOf(`gate{playerCounter}`, { factName }))
			maid:GiveTask(clientAccess:RegisterFeature(feature))

			return maid:Add(ObservableSpy.new(clientAccess:ObserveFeature(player, feature)))
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

type RealmPolicies = {
	serviceBag: ServiceBag.ServiceBag,
	accessPolicyService: any,
}

type PoliciesController = {
	maid: Maid.Maid,
	server: RealmPolicies,
	client: RealmPolicies,
	policyName: string,
	register: (
		self: PoliciesController,
		realm: RealmPolicies,
		isEnabledByDefault: boolean
	) -> AccessPolicy.AccessPolicy,
	Destroy: (self: PoliciesController) -> (),
}

local function setupPolicies(): PoliciesController
	local maid = Maid.new()

	local function realmPolicies(tieRealm: string): RealmPolicies
		local serviceBag = newRealmBag(tieRealm)
		local accessPolicyService = serviceBag:GetService(AccessPolicyService)
		serviceBag:Init()
		serviceBag:Start()

		return { serviceBag = serviceBag, accessPolicyService = accessPolicyService }
	end

	local server = realmPolicies(TieRealms.SERVER)
	local client = realmPolicies(TieRealms.CLIENT)

	maid:GiveTask(function()
		client.serviceBag:Destroy()
		server.serviceBag:Destroy()
	end)

	policyCounter += 1

	local controller: PoliciesController = {
		maid = maid,
		server = server,
		client = client,
		policyName = `chapterPaywall{policyCounter}`,
		register = function(self, realm, isEnabledByDefault)
			local policy = maid:Add(AccessPolicy.new(realm.serviceBag, {
				policyName = self.policyName,
				realm = AccessPolicyRealm.CLIENT,
				isEnabledByDefault = isEnabledByDefault,
				apply = function()
					return nil
				end,
			}))
			maid:GiveTask(realm.accessPolicyService:RegisterPolicy(policy))

			return policy
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("feature composition across realms", function()
	it("boots a server and a client bag", function()
		local controller = setup()

		expect(controller.server).never.toBeNil()
		expect(controller.client).never.toBeNil()

		controller:Destroy()
	end)

	it("carries a server-only push to the client", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))

		expect(clientFeature:GetFactNames()).toEqual({
			"ownsGame",
			controller.factName,
		})

		controller:Destroy()
	end)

	it("takes the push back when the server drops it", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local remove = serverFeature:PushFactNameAllowsFeature(controller.factName)
		expect(clientFeature:GetFactNames()).toEqual({
			"ownsGame",
			controller.factName,
		})

		remove()

		expect(clientFeature:GetFactNames()).toEqual({ "ownsGame" })

		controller:Destroy()
	end)

	it("reaches a client feature registered after the server pushed", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))

		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		expect(clientFeature:GetFactNames()).toEqual({
			"ownsGame",
			controller.factName,
		})

		controller:Destroy()
	end)

	it("changes what the client's verdict actually reads", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local ownsGame = controller.maid:Add(ValueObject.new(false))
		controller.maid:GiveTask(controller.client:RegisterFact(controller.maid:Add(AccessFact.new("ownsGame", {
			resolve = function()
				return ownsGame
			end,
		}))))

		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))
		expect(clientFeature:GetFactNames()).toEqual({ "ownsGame", controller.factName })

		local player = controller.maid:Add(PlayerMock.new())
		local states = controller.maid:Add(ObservableSpy.new(controller.client:ObserveFeature(player, clientFeature)))

		expect(AccessStateUtils.isUnresolved(states:GetLastValue())).toEqual(true)

		controller.client:SetServerFactValue(player, controller.factName, true)

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("leaves a fact the client pushed itself alone", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local removeOnServer = serverFeature:PushFactNameAllowsFeature("sharedAllowlist")
		expect(clientFeature:GetFactNames()).toEqual({ "ownsGame", "sharedAllowlist" })

		controller.maid:GiveTask(clientFeature:PushFactNameAllowsFeature("sharedAllowlist"))
		removeOnServer()

		expect(clientFeature:GetFactNames()).toEqual({ "ownsGame", "sharedAllowlist" })

		controller:Destroy()
	end)
end)

describe("per-player facts across realms", function()
	it("carries a console override to the client, closing a gate the client had opened", function()
		local controller = setupPlayers()
		controller:sharedFact(true)

		local states = controller:clientFeature()
		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller.maid:GiveTask(controller.server:SetFactOverride(controller.player, controller.factName, false))

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)

	it("carries a fact only the server can resolve to the client", function()
		local controller = setupPlayers()
		controller:serverFact(true)
		local states = controller:clientFeature()

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		controller:Destroy()
	end)

	it("follows the server when the answer changes", function()
		local controller = setupPlayers()
		local resolved = controller:serverFact(true)
		local states = controller:clientFeature()

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(true)

		resolved.Value = false

		expect(AccessStateUtils.isAllowed(states:GetLastValue())).toEqual(false)

		controller:Destroy()
	end)
end)

describe("the published composition and the service that wrote it", function()
	it("leaves a payload alone once somebody else has published over it", function()
		local controller = setup()
		controller:registerFeature(controller.server, { "ownsGame" })

		local other = HttpService:JSONEncode({ someoneElse = { "theirFact" } })
		ReplicatedStorage:SetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE, other)

		controller:Destroy()

		expect(ReplicatedStorage:GetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE)).toEqual(other)
		ReplicatedStorage:SetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE, nil)
	end)

	it("does not outlive the server that published it", function()
		local controller = setup()
		controller:registerFeature(controller.server, { "ownsGame" })

		expect(ReplicatedStorage:GetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE)).never.toEqual(nil)

		controller:Destroy()

		expect(ReplicatedStorage:GetAttribute(FEATURE_FACT_NAMES_ATTRIBUTE)).toEqual(nil)
	end)
end)

describe("policy enablement across realms", function()
	it("carries a policy switched off on the server to the client", function()
		local controller = setupPolicies()
		controller:register(controller.server, true)
		controller:register(controller.client, true)

		expect(controller.client.accessPolicyService:IsPolicyEnabled(controller.policyName)).toEqual(true)

		controller.server.accessPolicyService:SetPolicyEnabled(controller.policyName, false)

		expect(controller.client.accessPolicyService:IsPolicyEnabled(controller.policyName)).toEqual(false)

		controller:Destroy()
	end)

	it("carries a policy switched on on the server to the client", function()
		local controller = setupPolicies()
		controller:register(controller.server, false)
		controller:register(controller.client, false)

		expect(controller.client.accessPolicyService:IsPolicyEnabled(controller.policyName)).toEqual(false)

		controller.server.accessPolicyService:SetPolicyEnabled(controller.policyName, true)

		expect(controller.client.accessPolicyService:IsPolicyEnabled(controller.policyName)).toEqual(true)

		controller:Destroy()
	end)

	it("leaves a policy the server never registered alone", function()
		local controller = setupPolicies()
		controller:register(controller.client, true)

		expect(controller.client.accessPolicyService:IsPolicyEnabled(controller.policyName)).toEqual(true)

		controller:Destroy()
	end)
end)
