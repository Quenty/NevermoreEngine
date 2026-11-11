--!strict
--[[
	Coverage for the server chat-tag API against a PlayerMock. No real player joins a headless Open
	Cloud place, so a mock has to be able to reach a chat tag the same way a joined player does --
	through the PlayerBinder-backed HasChatTags, with the test creating nothing by hand but the mock.

	The built-in (dev) and (mod) tags are switched off per test: they resolve through PermissionService,
	which is a different question than whether a mock can be tagged at all.

	@class ChatProviderService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local ChatProviderService = require("ChatProviderService")
local ChatTagConstants = require("ChatTagConstants")
local ChatTagDataUtils = require("ChatTagDataUtils")
local HasChatTagsConstants = require("HasChatTagsConstants")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PermissionService = require("PermissionService")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local DEMO_TAG = ChatTagDataUtils.createChatTagData({
	TagText = "[DEMO]",
	TagPriority = 5,
	TagColor = Color3.fromRGB(245, 163, 27),
})

local remoteNameCounter = 0

local function waitForTagCount(player: Player, expected: number, timeout: number): number
	local deadline = os.clock() + timeout

	repeat
		local container = player:FindFirstChild(HasChatTagsConstants.TAG_CONTAINER_NAME)
		local count = if container then #container:GetChildren() else 0
		if count == expected then
			return count
		end
		task.wait(0.1)
	until os.clock() > deadline

	local container = player:FindFirstChild(HasChatTagsConstants.TAG_CONTAINER_NAME)
	return if container then #container:GetChildren() else 0
end

local function setup(creatorUserId: number?)
	local maid = Maid.new()

	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "ChatProviderServiceSpecContainer"
	container.Parent = workspace

	local chatProviderService: any = serviceBag:GetService(ChatProviderService)
	local permissionService: any = serviceBag:GetService(PermissionService)
	local playerMockService: any = serviceBag:GetService(PlayerMockService)

	serviceBag:Init()

	if creatorUserId then
		remoteNameCounter += 1
		permissionService:SetProviderFromConfig(PermissionProviderUtils.createSingleUserConfig({
			userId = creatorUserId,
			remoteFunctionName = string.format("ChatProviderServiceSpecRemote%d", remoteNameCounter),
		}))
	end

	serviceBag:Start()

	if not creatorUserId then
		chatProviderService:SetDeveloperTag(nil)
		chatProviderService:SetAdminTag(nil)
	end

	local mocks: { Player } = {}
	local bagDestroyed = false

	local function destroyBag()
		if not bagDestroyed then
			bagDestroyed = true
			serviceBag:Destroy()
		end
	end

	maid:GiveTask(function()
		destroyBag()

		for _, mock in mocks do
			mock:Destroy()
		end
		table.clear(mocks)

		container:Destroy()
	end)

	local controller = {
		chatProviderService = chatProviderService,
		newMock = function(userId: number?): Player
			local mock = playerMockService:CreatePlayer(if userId then { UserId = userId } else nil)
			mock.Parent = container
			table.insert(mocks, mock)
			return mock
		end,
		destroyBag = destroyBag,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("ChatProviderService.PromiseAddChatTag", function()
	it("tags a player mock", function()
		local controller = setup()
		local player = controller.newMock()

		local tag = controller.chatProviderService:PromiseAddChatTag(player, DEMO_TAG):Wait()

		expect(tag:GetAttribute(ChatTagConstants.TAG_TEXT_ATTRIBUTE)).toBe(DEMO_TAG.TagText)
		expect(tag:IsDescendantOf(player)).toBe(true)
	end)

	it("drops the tag when the instance is destroyed", function()
		local controller = setup()
		local player = controller.newMock()

		local tag = controller.chatProviderService:PromiseAddChatTag(player, DEMO_TAG):Wait()
		tag:Destroy()

		expect(tag:IsDescendantOf(player)).toBe(false)
	end)
end)

describe("ChatProviderService.SetDeveloperTag", function()
	local CREATOR_USER_ID = 4242

	it("tags the creator", function()
		local controller = setup(CREATOR_USER_ID)
		local player = controller.newMock(CREATOR_USER_ID)

		expect(waitForTagCount(player, 1, 10)).toBe(1)
	end)

	it("leaves everybody else alone", function()
		local controller = setup(CREATOR_USER_ID)
		local player = controller.newMock(CREATOR_USER_ID + 1)

		expect(waitForTagCount(player, 0, 3)).toBe(0)
	end)

	--[[
		The tag holds a subscription to every player in the place, so without a Destroy it outlived its
		own bag: a destroyed service went on resolving permissions and reaching for binders through
		services it no longer owned.
	]]
	it("stops tagging once its bag is destroyed", function()
		local controller = setup(CREATOR_USER_ID)
		controller.destroyBag()

		local player = controller.newMock(CREATOR_USER_ID)

		expect(waitForTagCount(player, 0, 3)).toBe(0)
	end)
end)

describe("ChatProviderService.ClearChatTags", function()
	it("clears a player mock's tags", function()
		local controller = setup()
		local player = controller.newMock()

		local tag = controller.chatProviderService:PromiseAddChatTag(player, DEMO_TAG):Wait()
		controller.chatProviderService:ClearChatTags(player)

		expect(tag.Parent).toBe(nil)
	end)
end)
