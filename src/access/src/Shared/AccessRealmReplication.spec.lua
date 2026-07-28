--!strict
--[[
	Replication with both halves actually booted, rather than each half driven at its seam.

	A SERVER and a CLIENT ServiceBag come up in the same DataModel -- the realm comes from
	[TieRealmService], which is the one realm answer a bag can be told -- and the two are exercised against
	each other through the transport they really use. What the seam tests cannot show is the wiring between
	them: that the server publishes at all, that the client is listening, and that the two agree on where
	to look.

	Every assertion here waits for the client to converge. Replication is asynchronous even inside one
	DataModel -- an attribute change notifies on the next resumption point, not inside the call that made
	it -- and a test that read the client synchronously would be asserting a fiction.

	@class AccessRealmReplication.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessDataService = require("AccessDataService")
local AccessFact = require("AccessFact")
local AccessFactServerOverrideBehavior = require("AccessFactServerOverrideBehavior")
local AccessFeature = require("AccessFeature")
local AccessService = require("AccessService")
local AccessServiceClient = require("AccessServiceClient")
local AccessStateUtils = require("AccessStateUtils")
local Jest = require("Jest")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local afterEach = Jest.Globals.afterEach
local it = Jest.Globals.it

local CONVERGE_FRAMES = 120

local featureCounter = 0

-- Returns as soon as the realms agree, and returns whatever the client has if they never do -- so a
-- failure prints the real difference rather than a timeout.
local function waitForFactNames(feature: any, expected: { string }): { string }
	for _ = 1, CONVERGE_FRAMES do
		local names = feature:GetFactNames()
		if table.concat(names, "\0") == table.concat(expected, "\0") then
			return names
		end

		task.wait()
	end

	return feature:GetFactNames()
end

local function setup()
	local maid = Maid.new()

	-- The realm has to be set before Init: TieRealmService infers one there, and only if it has not been
	-- told.
	local function bag(tieRealm: string)
		local serviceBag = maid:Add(ServiceBag.new());
		(serviceBag:GetService(TieRealmService) :: any):SetTieRealm(tieRealm)
		local accessDataService = serviceBag:GetService(AccessDataService) :: any
		serviceBag:Init()
		serviceBag:Start()

		return accessDataService
	end

	local server = bag(TieRealms.SERVER)
	local client = bag(TieRealms.CLIENT)

	featureCounter += 1
	local featureName = `chapters{featureCounter}`

	return {
		maid = maid,
		server = server,
		client = client,
		-- Unique per test: the registries are per-bag, but the attribute they meet on is not, so a name
		-- reused across tests would have one test reading another's publication.
		featureName = featureName,
		factName = `gamePass{featureCounter}`,
		registerFeature = function(_self, accessDataService: any, factNames: { string })
			local feature = maid:Add(AccessFeature.anyOf(featureName, factNames))
			maid:GiveTask(accessDataService:RegisterFeature(feature))
			return feature
		end,
		destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

describe("feature composition across realms", function()
	it("boots a server and a client bag", function()
		local controller = setup()

		expect(controller.server).never.toBeNil()
		expect(controller.client).never.toBeNil()

		controller:destroy()
	end)

	it("carries a server-only push to the client", function()
		-- The failure this guards: a game widens a feature in server code, and the client keeps gating on
		-- the narrower rule -- two realms reaching different verdicts about the same player.
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))

		expect(waitForFactNames(clientFeature, { "ownsGame", controller.factName })).toEqual({
			"ownsGame",
			controller.factName,
		})

		controller:destroy()
	end)

	it("takes the push back when the server drops it", function()
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local remove = serverFeature:PushFactNameAllowsFeature(controller.factName)
		expect(waitForFactNames(clientFeature, { "ownsGame", controller.factName })).toEqual({
			"ownsGame",
			controller.factName,
		})

		remove()

		expect(waitForFactNames(clientFeature, { "ownsGame" })).toEqual({ "ownsGame" })

		controller:destroy()
	end)

	it("reaches a client feature registered after the server pushed", function()
		-- Neither realm's registration order is the other's to control.
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))

		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		expect(waitForFactNames(clientFeature, { "ownsGame", controller.factName })).toEqual({
			"ownsGame",
			controller.factName,
		})

		controller:destroy()
	end)

	it("changes what the client's verdict actually reads", function()
		-- Widening the list is only worth anything if the merge picks it up: the client has no resolver for
		-- the pushed fact, so its answer can only come from the per-player replication.
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local ownsGame = controller.maid:Add(ValueObject.new(false)) :: any
		controller.maid:GiveTask(controller.client:RegisterFact(controller.maid:Add(AccessFact.new("ownsGame", {
			resolve = function()
				return ownsGame
			end,
		}))))

		controller.maid:GiveTask(serverFeature:PushFactNameAllowsFeature(controller.factName))
		waitForFactNames(clientFeature, { "ownsGame", controller.factName })

		local player = controller.maid:Add(PlayerMock.new()) :: any
		local last = nil
		controller.maid:GiveTask(controller.client:ObserveFeature(player, clientFeature):Subscribe(function(state)
			last = state
		end))

		-- Unresolved rather than denied: the client now knows the pushed fact is expected, and has no
		-- answer for it.
		expect(AccessStateUtils.isUnresolved(last :: any)).toEqual(true)

		controller.client:SetServerFactValue(player, controller.factName, true)

		expect(AccessStateUtils.isAllowed(last :: any)).toEqual(true)

		controller:destroy()
	end)

	it("leaves a fact the client pushed itself alone", function()
		-- Replication widens a feature on the client; it does not own it.
		--
		-- Pushed on *both* realms, and in the order that used to break it: the reconciler claims the name
		-- first, the client's own code claims it second, and the server then drops it. A push that returned
		-- a no-op remover for an already-present name gave the reconciler sole ownership, so its remover
		-- took away a grant the client had made and expected to keep.
		local controller = setup()
		local serverFeature = controller:registerFeature(controller.server, { "ownsGame" })
		local clientFeature = controller:registerFeature(controller.client, { "ownsGame" })

		local removeOnServer = serverFeature:PushFactNameAllowsFeature("sharedAllowlist")
		waitForFactNames(clientFeature, { "ownsGame", "sharedAllowlist" })

		controller.maid:GiveTask(clientFeature:PushFactNameAllowsFeature("sharedAllowlist"))
		removeOnServer()

		-- Several frames, so the reconcile that follows the server's drop has certainly run.
		for _ = 1, 10 do
			task.wait()
		end

		expect(clientFeature:GetFactNames()).toEqual({ "ownsGame", "sharedAllowlist" })

		controller:destroy()
	end)
end)

describe("per-player facts across realms", function()
	--[[
		The other half of replication, and the one that runs through the binders: the server resolves a fact
		nobody else can and writes it onto the player, and the client's registry answers with it.

		Asserted through a feature verdict rather than through a fact readout, because the verdict is what a
		game actually reads -- and because a client legitimately has no report for a fact it has not been
		told about yet, which is the very window being waited out.

		Both realms' binders share a tag, which in one DataModel means both bind the same mock. That is the
		arrangement under test, not a problem with it.
	]]
	local playerCounter = 0

	-- Torn down here rather than at the end of each test, because a failing test never reaches its last
	-- line. The AccessPlayer tag is global: a binder that outlives its test goes on binding the next
	-- test's player and overwriting the facts attribute from its own registry, so one failure would take
	-- every later test with it and none of them would say why.
	local live: any = nil
	afterEach(function()
		if live then
			live:destroy()
			live = nil
		end
	end)

	local function setupPlayers()
		local maid = Maid.new()

		local serverBag = maid:Add(ServiceBag.new());
		(serverBag:GetService(TieRealmService) :: any):SetTieRealm(TieRealms.SERVER)
		local serverAccess: any = serverBag:GetService(AccessDataService)
		serverBag:GetService(AccessService)
		serverBag:Init()
		serverBag:Start()

		local clientBag = maid:Add(ServiceBag.new());
		(clientBag:GetService(TieRealmService) :: any):SetTieRealm(TieRealms.CLIENT)
		local clientAccess: any = clientBag:GetService(AccessDataService)
		clientBag:GetService(AccessServiceClient)
		clientBag:Init()
		clientBag:Start()

		-- Mocks have to come from the service: a bare PlayerMock.new() is not tracked, so the binder would
		-- never discover it.
		local playerMockService: any = serverBag:GetService(PlayerMockService)

		playerCounter += 1
		local factName = `serverOnly{playerCounter}`

		local controller: any
		controller = {
			maid = maid,
			server = serverAccess,
			client = clientAccess,
			factName = factName,
			player = maid:Add(playerMockService:CreatePlayer()) :: any,
			serverFact = function(_self, value: boolean?)
				local resolved = maid:Add(ValueObject.new(value)) :: any
				maid:GiveTask(serverAccess:RegisterFact(maid:Add(AccessFact.new(factName, {
					resolve = function()
						return resolved
					end,
					serverOverrideBehavior = AccessFactServerOverrideBehavior.SERVER_OVERRIDE_ALL,
				}))))
				return resolved
			end,
			-- Registered only on the client, reading a fact only the server can answer. Exactly the shape a
			-- receipt in a server-only DataStore has.
			clientFeature = function(_self)
				local feature = maid:Add(AccessFeature.anyOf(`gate{playerCounter}`, { factName }))
				maid:GiveTask(clientAccess:RegisterFeature(feature))

				local last = nil
				maid:GiveTask(clientAccess:ObserveFeature(_self.player, feature):Subscribe(function(state)
					last = state
				end))

				return function()
					return last
				end
			end,
			destroy = function(_self)
				-- Client first: the server bag owns the mock, and destroying it out from under a live client
				-- is not something production ever does.
				clientBag:Destroy()
				serverBag:Destroy()
			end,
		}

		live = controller
		return controller
	end

	local function waitUntil(predicate: () -> boolean): boolean
		for _ = 1, CONVERGE_FRAMES do
			if predicate() then
				return true
			end

			task.wait()
		end

		return false
	end

	it("carries a console override to the client, closing a gate the client had opened", function()
		-- The reason overrides replicate as overrides rather than as values: the client resolves ownsGame
		-- for itself and says yes, and under the default behaviour a replicated `false` can never take that
		-- back. An override is a debugging instruction and has to land in both realms or it is worse than
		-- not landing at all -- the server's gate open, the client's shut, neither readout saying why.
		local controller = setupPlayers()
		local resolved = controller.maid:Add(ValueObject.new(true)) :: any
		controller.maid:GiveTask(
			controller.client:RegisterFact(controller.maid:Add(AccessFact.new(controller.factName, {
				resolve = function()
					return resolved
				end,
			})))
		)
		controller.maid:GiveTask(
			controller.server:RegisterFact(controller.maid:Add(AccessFact.new(controller.factName, {
				resolve = function()
					return resolved
				end,
			})))
		)

		local state = controller:clientFeature()
		expect(waitUntil(function()
			return AccessStateUtils.isAllowed(state() :: any)
		end)).toEqual(true)

		controller.maid:GiveTask(controller.server:SetFactOverride(controller.player, controller.factName, false))

		expect(waitUntil(function()
			return not AccessStateUtils.isAllowed(state() :: any)
		end)).toEqual(true)
	end)

	it("carries a fact only the server can resolve to the client", function()
		local controller = setupPlayers()
		controller:serverFact(true)
		local state = controller:clientFeature()

		expect(waitUntil(function()
			return AccessStateUtils.isAllowed(state() :: any)
		end)).toEqual(true)
	end)

	it("follows the server when the answer changes", function()
		local controller = setupPlayers()
		local resolved = controller:serverFact(true)
		local state = controller:clientFeature()

		expect(waitUntil(function()
			return AccessStateUtils.isAllowed(state() :: any)
		end)).toEqual(true)

		resolved.Value = false

		expect(waitUntil(function()
			return not AccessStateUtils.isAllowed(state() :: any)
		end)).toEqual(true)
	end)
end)

describe("the published composition and the service that wrote it", function()
	it("leaves a payload alone once somebody else has published over it", function()
		-- One attribute, one slot. Taking down a composition another live service is gating on is worse
		-- than the stale payload the cleanup exists to prevent.
		local controller = setup()
		controller:registerFeature(controller.server, { "ownsGame" })
		for _ = 1, 10 do
			task.wait()
		end

		local other = { someoneElse = { "theirFact" } }
		ReplicatedStorage:SetAttribute("AccessFeatureFactNames", HttpService:JSONEncode(other))

		controller:destroy()

		expect(ReplicatedStorage:GetAttribute("AccessFeatureFactNames")).toEqual(HttpService:JSONEncode(other))
		ReplicatedStorage:SetAttribute("AccessFeatureFactNames", nil)
	end)

	it("does not outlive the server that published it", function()
		-- The attribute lives on ReplicatedStorage, which outlives any service bag. A stale payload left
		-- behind is read by the next service to come up as though it were current.
		local controller = setup()
		controller:registerFeature(controller.server, { "ownsGame" })

		for _ = 1, 10 do
			task.wait()
		end
		expect(ReplicatedStorage:GetAttribute("AccessFeatureFactNames")).never.toEqual(nil)

		controller:destroy()

		expect(ReplicatedStorage:GetAttribute("AccessFeatureFactNames")).toEqual(nil)
	end)
end)
