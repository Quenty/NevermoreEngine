--!nonstrict
--[=[
	Helpers for the player binder specs, with init and start split so mocks can be staged in between.

	@class PlayerHumanoidBinderTestUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BinderTestUtils = require("BinderTestUtils")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")

local PlayerHumanoidBinderTestUtils = {}

--[=[
	Builds a controller around one binder of the given class, registered in a [ServiceBag].

	@param binderClass PlayerCharacterBinder | PlayerHumanoidBinder
	@param tagPrefix string -- keeps tags distinct between the two spec files
	@param constructor any? -- defaults to a fresh tracking class
	@return { ... }
]=]
function PlayerHumanoidBinderTestUtils.setup(binderClass, tagPrefix, constructor)
	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	maid._serviceBag = serviceBag

	local container = Instance.new("Folder")
	container.Name = string.format("%sSpecContainer", tagPrefix)
	container.Parent = workspace

	local instances = {}

	local tag = string.format("%sSpecTag_%s", tagPrefix, HttpService:GenerateGUID(false))
	local binder = serviceBag:GetService(binderClass.new(tag, constructor or BinderTestUtils.makeTrackingClass()))
	local playerMockService = serviceBag:GetService(PlayerMockService)

	local function init()
		serviceBag:Init()
	end

	local function start()
		serviceBag:Start()
	end

	local function initServiceBag()
		serviceBag:Init()
		serviceBag:Start()
	end

	local function newMock(userId)
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

	maid:GiveTask(function()
		maid._serviceBag = nil
		for _, inst in instances do
			pcall(function()
				inst:Destroy()
			end)
		end
		container:Destroy()
	end)

	maid:GiveTask(JestUtils.afterThis(maid))

	return maid:Add({
		binder = binder,
		tag = tag,
		init = init,
		start = start,
		initServiceBag = initServiceBag,
		newMock = newMock,
		newCharacter = newCharacter,
		setCharacter = setCharacter,
		loadCharacter = loadCharacter,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	})
end

return PlayerHumanoidBinderTestUtils
