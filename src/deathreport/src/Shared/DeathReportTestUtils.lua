--!nonstrict
--[=[
	Shared harness for the deathreport specs. [DeathReportTestUtils.setup] boots [DeathReportService]
	the way production does -- through a [ServiceBag] -- and optionally a second, client-realm bag
	running [DeathReportServiceClient] against it over dummy-mode remoting. Real players never join a
	headless place, so players are [PlayerMock]s created through the server bag's [PlayerMockService],
	and a character is spawned with [PlayerMock.loadMinimalCharacterAsync] so [DeathTrackedHumanoid]
	discovers it like a real join.

	Binders are exposed as resolved by the bags (`teamKillTrackerBinder`, ...): a ServiceBag
	instantiates its own isolated copy of every service it runs, so the module value a spec requires
	is never the binder that was started, and binding through it fails.

	The test place is shared across a batch run, so every controller derives distinct user ids from a
	module-level counter and tears down everything it created via `Destroy()` -- client bag first, then
	the server bag that owns the mocks.

	@class DeathReportTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local DeathReportService = require("DeathReportService")
local DeathReportServiceClient = require("DeathReportServiceClient")
local DeathTrackedHumanoid = require("DeathTrackedHumanoid")
local HumanoidKillerUtils = require("HumanoidKillerUtils")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerDeathTracker = require("PlayerDeathTracker")
local PlayerDeathTrackerClient = require("PlayerDeathTrackerClient")
local PlayerKillTracker = require("PlayerKillTracker")
local PlayerKillTrackerClient = require("PlayerKillTrackerClient")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local PlayerMockServiceClient = require("PlayerMockServiceClient")
local ServiceBag = require("ServiceBag")
local TeamKillTracker = require("TeamKillTracker")
local TeamKillTrackerClient = require("TeamKillTrackerClient")

local DeathReportTestUtils = {}

local USER_ID_BASE = 55210000

local specCounter = 0

--[=[
	Polls until the condition passes or the timeout elapses. Returns the final condition result so
	specs can `expect(...).toBe(true)` on it.

	@param condition () -> boolean
	@param timeout number?
	@return boolean
]=]
function DeathReportTestUtils.waitFor(condition, timeout)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait()
	end
	return condition()
end

--[=[
	Yields until the binder has bound the instance and returns the bound class.

	@param binder Binder<T>
	@param inst Instance
	@return T
]=]
function DeathReportTestUtils.awaitBound(binder, inst)
	local ok, class = binder:Promise(inst):Yield()
	assert(ok, string.format("%q never bound", binder:GetTag()))
	return class
end

--[=[
	Returns once `inst` is no longer bound. Removal is usually already done by the time we check; the
	guarded wait also covers a deferred case.

	@param binder Binder<T>
	@param inst Instance
]=]
function DeathReportTestUtils.awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

--[=[
	Builds the controller the specs share.

	Fields: `maid`, `serverBag`, `deathReportService`, `playerMockService`, `container`, the server
	binders `teamKillTrackerBinder`, `playerKillTrackerBinder`, `playerDeathTrackerBinder`, and with
	`withClient`: `clientBag`, `deathReportServiceClient`, `playerMockServiceClient` and the client
	binders `teamKillTrackerClientBinder`, `playerKillTrackerClientBinder`, `playerDeathTrackerClientBinder`.
	Builders: `newMock(overrides?)` -> Player, `newCharacter(mock)` -> (Model, Humanoid) bound to
	[DeathTrackedHumanoid], `newNpc(name?)` -> (Model, Humanoid) untracked, `newTeam(name?, brickColor?)`
	-> Team.
	Actions: `setTeam(mock, team?)`, `setLocalPlayer(mock)`, `kill(humanoid, killer?)`.
	Lifecycle: `destroyClientBag()`, `destroyServerBag()`, `Destroy()`.

	@param options { withClient: boolean? }?
	@return { ... }
]=]
function DeathReportTestUtils.setup(options)
	options = options or {}

	specCounter += 1
	local suffix = specCounter

	local maid = Maid.new()

	local container = Instance.new("Folder")
	container.Name = string.format("DeathReportSpecContainer_%d", suffix)
	container.Parent = Workspace

	local instances = {}

	local serverBag = ServiceBag.new()
	local deathReportService = serverBag:GetService(DeathReportService)
	local playerMockService = serverBag:GetService(PlayerMockService)
	serverBag:Init()
	serverBag:Start()

	local deathTrackedHumanoidBinder = serverBag:GetService(DeathTrackedHumanoid)

	local clientBag, deathReportServiceClient, playerMockServiceClient
	if options.withClient then
		clientBag = ServiceBag.new()
		deathReportServiceClient = clientBag:GetService(DeathReportServiceClient)
		playerMockServiceClient = clientBag:GetService(PlayerMockServiceClient)
		clientBag:Init()
		clientBag:Start()
	end

	local clientBagDestroyed = false
	local function destroyClientBag()
		if clientBag and not clientBagDestroyed then
			clientBagDestroyed = true
			clientBag:Destroy()
		end
	end

	local serverBagDestroyed = false
	local function destroyServerBag()
		if not serverBagDestroyed then
			serverBagDestroyed = true
			serverBag:Destroy()
		end
	end

	local mockCounter = 0
	local function newMock(overrides)
		mockCounter += 1

		local seed = { UserId = USER_ID_BASE + suffix * 100 + mockCounter }
		if overrides then
			for key, value in overrides do
				seed[key] = value
			end
		end

		return playerMockService:CreatePlayer(seed)
	end

	local function newCharacter(mock)
		local character = PlayerMock.loadMinimalCharacterAsync(mock)
		local humanoid = assert(character:FindFirstChildWhichIsA("Humanoid"), "No humanoid")

		DeathReportTestUtils.awaitBound(deathTrackedHumanoidBinder, humanoid)

		return character, humanoid
	end

	local function newNpc(name)
		local character = Instance.new("Model")
		character.Name = name or "Npc"

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character

		character.Parent = container
		table.insert(instances, character)

		return character, humanoid
	end

	local teamCounter = 0
	local function newTeam(name, brickColor)
		teamCounter += 1

		local team = Instance.new("Team")
		team.Name = name or string.format("DeathReportSpecTeam_%d_%d", suffix, teamCounter)
		team.TeamColor = brickColor or BrickColor.new("Bright red")
		team.AutoAssignable = false
		team.Parent = Teams
		table.insert(instances, team)

		return team
	end

	local function setTeam(mock, team)
		PlayerMock.write(mock, "Team", team)
		PlayerMock.write(mock, "Neutral", team == nil)
	end

	local function setLocalPlayer(mock)
		assert(playerMockServiceClient, "No client bag -- pass withClient")
		playerMockServiceClient:SetLocalPlayer(mock)
	end

	local function kill(humanoid, killer)
		if killer then
			HumanoidKillerUtils.tagKiller(humanoid, killer)
		end

		humanoid.Health = 0
	end

	maid:GiveTask(function()
		-- Client bags first: the server bag owns the mocks, and destroying them out from under a
		-- live client is not something production ever does.
		destroyClientBag()
		destroyServerBag()

		for _, inst in instances do
			pcall(function()
				inst:Destroy()
			end)
		end
		container:Destroy()
	end)

	local controller = {
		maid = maid,
		container = container,
		serverBag = serverBag,
		deathReportService = deathReportService,
		playerMockService = playerMockService,
		teamKillTrackerBinder = serverBag:GetService(TeamKillTracker),
		playerKillTrackerBinder = serverBag:GetService(PlayerKillTracker),
		playerDeathTrackerBinder = serverBag:GetService(PlayerDeathTracker),
		clientBag = clientBag,
		deathReportServiceClient = deathReportServiceClient,
		playerMockServiceClient = playerMockServiceClient,
		teamKillTrackerClientBinder = clientBag and clientBag:GetService(TeamKillTrackerClient),
		playerKillTrackerClientBinder = clientBag and clientBag:GetService(PlayerKillTrackerClient),
		playerDeathTrackerClientBinder = clientBag and clientBag:GetService(PlayerDeathTrackerClient),
		newMock = newMock,
		newCharacter = newCharacter,
		newNpc = newNpc,
		newTeam = newTeam,
		setTeam = setTeam,
		setLocalPlayer = setLocalPlayer,
		kill = kill,
		destroyClientBag = destroyClientBag,
		destroyServerBag = destroyServerBag,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

return DeathReportTestUtils
