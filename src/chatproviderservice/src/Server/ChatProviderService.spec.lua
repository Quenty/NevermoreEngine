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
local Jest = require("Jest")
local PlayerMockService = require("PlayerMockService")
local ServiceBag = require("ServiceBag")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local DEMO_TAG = ChatTagDataUtils.createChatTagData({
	TagText = "[DEMO]",
	TagPriority = 5,
	TagColor = Color3.fromRGB(245, 163, 27),
})

local activeController: any = nil

afterEach(function()
	if activeController then
		local controller = activeController
		activeController = nil
		controller.destroy()
	end
end)

local function setup()
	local serviceBag = ServiceBag.new()
	local container = Instance.new("Folder")
	container.Name = "ChatProviderServiceSpecContainer"
	container.Parent = workspace

	local chatProviderService: any = serviceBag:GetService(ChatProviderService)
	local playerMockService: any = serviceBag:GetService(PlayerMockService)

	serviceBag:Init()
	serviceBag:Start()

	chatProviderService:SetDeveloperTag(nil)
	chatProviderService:SetAdminTag(nil)

	local mocks: { Player } = {}

	local controller
	controller = {
		chatProviderService = chatProviderService,
		newMock = function(): Player
			local mock = playerMockService:CreatePlayer()
			mock.Parent = container
			table.insert(mocks, mock)
			return mock
		end,
		destroy = function()
			for _, mock in mocks do
				mock:Destroy()
			end
			table.clear(mocks)

			serviceBag:Destroy()
			container:Destroy()
		end,
	}

	activeController = controller
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

describe("ChatProviderService.ClearChatTags", function()
	it("clears a player mock's tags", function()
		local controller = setup()
		local player = controller.newMock()

		local tag = controller.chatProviderService:PromiseAddChatTag(player, DEMO_TAG):Wait()
		controller.chatProviderService:ClearChatTags(player)

		expect(tag.Parent).toBe(nil)
	end)
end)
