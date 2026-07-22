--!nonstrict
--[=[
	Shared harness for the PlayerCharacterBinder/PlayerHumanoidBinder specs. [setup] boots a binder the
	way production does -- registered on a [BinderProvider] driven through a [ServiceBag] -- with the boot
	split into init()/start() so a test can stage mocks before the binder starts. Mocks are created
	through the bag's [PlayerMockService] (so discovery mirrors a real join, and teardown destroys them --
	discovery is place-wide, so a leaked mock would bleed into the next test), and characters are plain
	Models with a real Humanoid.

	Tags are global and the test place is shared across a batch run, so every controller derives a
	distinct tag from a single module-level counter, parents everything under its own container, and
	tears it all down via destroy().

	@class PlayerHumanoidBinderTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")

local PlayerHumanoidBinderTestUtils = {}

-- A single counter shared across both spec files that require this module, so the tags it hands out
-- never collide within the shared batch place.
local specCounter = 0

--[=[
	A minimal bound class that records its instance and whether it was destroyed. It ignores its
	constructor varargs: the ServiceBag is injected as a constructor arg, and its Signals' strict
	__index makes jest's deep-equality traversal throw, so the class must not retain it for toEqual to
	compare instances safely.

	@return TrackingClass
]=]
function PlayerHumanoidBinderTestUtils.makeTrackingClass()
	local Class = {}
	Class.__index = Class
	Class.ClassName = "TrackingClass"

	function Class.new(inst)
		return setmetatable({ instance = inst, destroyed = false }, Class)
	end

	function Class:Destroy()
		self.destroyed = true
	end

	return Class
end

--[=[
	Returns once `inst` is no longer bound. Removal is usually already done by the time we check; the
	guarded wait also covers a deferred case.

	@param binder Binder
	@param inst Instance
]=]
function PlayerHumanoidBinderTestUtils.awaitUnbound(binder, inst)
	if binder:Get(inst) ~= nil then
		binder:GetClassRemovedSignal():Wait()
	end
end

--[=[
	Builds the controller the specs share around one binder of the given class. init() registers and
	Init's the bag (mocks can then be staged), start() starts it, boot() does both. newMock() creates a
	player through the bag's PlayerMockService; newCharacter() builds a character Model (with a real
	Humanoid unless withHumanoid is false); setCharacter() assigns the mock's stand-in Character.

	@param binderClass PlayerCharacterBinder | PlayerHumanoidBinder
	@param tagPrefix string -- keeps tags distinct between the two spec files
	@param constructor any? -- defaults to a fresh tracking class
	@return { ... }
]=]
function PlayerHumanoidBinderTestUtils.setup(binderClass, tagPrefix, constructor)
	specCounter += 1
	local suffix = specCounter

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = string.format("%sSpecContainer_%d", tagPrefix, suffix)
	container.Parent = workspace

	local instances = {}
	local initialized = false
	local started = false

	local tag = string.format("%sSpecTag_%d", tagPrefix, suffix)
	local binder = binderClass.new(tag, constructor or PlayerHumanoidBinderTestUtils.makeTrackingClass())
	local playerMockService = serviceBag:GetService(PlayerMockService)

	local function init()
		assert(not initialized, "Already initialized")
		initialized = true

		local provider = BinderProvider.new(string.format("%sSpecProvider_%d", tagPrefix, suffix), function(self)
			self:Add(binder)
		end)
		serviceBag:GetService(provider)
		serviceBag:Init()
	end

	local function start()
		assert(initialized, "Call init() first")
		assert(not started, "Already started")
		started = true

		serviceBag:Start()
	end

	local function boot()
		init()
		start()
	end

	local function newMock(userId)
		assert(initialized, "Call init() first -- mocks are created through the bag's PlayerMockService")

		local mock = playerMockService:CreatePlayer(if userId ~= nil then { UserId = userId } else nil)
		mock.Parent = container
		table.insert(instances, mock)
		return mock
	end

	local function newCharacter(withHumanoid)
		local character = Instance.new("Model")
		character.Name = string.format("%sSpecCharacter", tagPrefix)

		local humanoid = nil
		if withHumanoid ~= false then
			humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
		end

		character.Parent = container
		table.insert(instances, character)
		return character, humanoid
	end

	local function setCharacter(mock, character)
		PlayerMock.write(mock, "Character", character)
	end

	-- Spawns the character the way the engine does (fires CharacterAdded, reparents to Workspace,
	-- despawns any previous character). A bare setCharacter write deliberately does not fire
	-- CharacterAdded -- see PlayerMock.loadCharacterAsync.
	local function loadCharacter(mock, character)
		return PlayerMock.loadCharacterAsync(mock, character)
	end

	local function destroy()
		if initialized then
			serviceBag:Destroy()
		end
		for _, inst in instances do
			pcall(function()
				inst:Destroy()
			end)
		end
		container:Destroy()
	end

	return {
		binder = binder,
		tag = tag,
		init = init,
		start = start,
		boot = boot,
		newMock = newMock,
		newCharacter = newCharacter,
		setCharacter = setCharacter,
		loadCharacter = loadCharacter,
		destroy = destroy,
	}
end

return PlayerHumanoidBinderTestUtils
