--[=[
	@class ChatProviderCommandService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local ChatTagCmdrUtils = require("ChatTagCmdrUtils")
local ChatTagDataUtils = require("ChatTagDataUtils")
local PlayerUtils = require("PlayerUtils")
local Set = require("Set")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local ChatProviderCommandService = {}
ChatProviderCommandService.ServiceName = "ChatProviderCommandService"

function ChatProviderCommandService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
	self._permissionService = self._serviceBag:GetService(require("PermissionService"))

	-- Internal
	self._chatProviderService = self._serviceBag:GetService((require :: any)("ChatProviderService"))
	self._chatTagBinder = self._serviceBag:GetService(require("ChatTag"))
	self._hasChatTagsBinder = self._serviceBag:GetService(require("HasChatTags"))
end

function ChatProviderCommandService:Start()
	self:_registerCommands()
	self:_createActivateChatCommand()
end

function ChatProviderCommandService:_createActivateChatCommand()
	local command = Instance.new("TextChatCommand")
	command.Name = "OpenCmdrCommand"
	command.PrimaryAlias = "/cmdr"

	self._maid:GiveTask(command)
	self._maid:GiveTask(command.Triggered:Connect(function(originTextSource, _unfilteredText)
		local player = Players:GetPlayerByUserId(originTextSource.UserId)
		if not player then
			return
		end

		self._permissionService:PromiseIsAdmin(player):Then(function(isAdmin)
			if isAdmin then
				self._remoting.OpenCmdr:FireClient(player)
			end
		end)
	end))

	self._chatProviderService:AddChatCommand(command)
end


function ChatProviderCommandService:GetChatTagKeyList()
	local tagSet = {}
	for chatTag, _ in pairs(self._chatTagBinder:GetAllSet()) do
		local tagKey = chatTag.ChatTagKey.Value
		tagSet[tagKey] = true
	end

	return Set.toList(tagSet)
end

function ChatProviderCommandService:_registerCommands()
	self._cmdrService:PromiseCmdr():Then(function(cmdr)
		ChatTagCmdrUtils.registerChatTagKeys(cmdr, self)
	end)

	self._cmdrService:RegisterCommand({
		Name = "add-chat-tag";
		Aliases = { };
		Description = "Adds a tag to a player";
		Group = "ChatTags";
		Args = {
			{
				Name = "Target";
				Type = "player";
				Description = "Player to add a tag for";
			},
			{
				Name = "TagText";
				Type = "string";
				Description = "Text for the tag to have";
			},
			{
				Name = "TagColor";
				Type = "color3";
				Description = "Color for the tag to have";
				Optional = true;
				Default = Color3.fromRGB(255, 170, 0);
			},
			{
				Name = "TagPriority";
				Type = "number";
				Description = "Priority for the tag to have";
				Optional = true;
				Default = 0;
			},
		};
	}, function(_context, player, tagText, tagColor, priority)
		self._chatProviderService:PromiseAddChatTag(player, ChatTagDataUtils.createChatTagData({
			TagText = tagText;
			TagPriority = priority or 0;
			TagColor = tagColor or Color3.fromRGB(255, 170, 0);
		}))

		return string.format("Added tag %q to player %q", tagText, PlayerUtils.formatName(player))
	end)

	self._cmdrService:RegisterCommand({
		Name = "clear-chat-tags";
		Aliases = { };
		Description = "Clears chat tags on a player";
		Group = "ChatTags";
		Args = {
			{
				Name = "Target";
				Type = "player";
				Description = "Player to add a tag for";
			}
		};
	}, function(_context, player)
		self._chatProviderService:ClearChatTags(player)

		return string.format("Cleared chat tags on a player %q", PlayerUtils.formatName(player))
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-chat-tag-disabled";
		Aliases = { };
		Description = "Sets if a chat tag is disabled for a player. This will save.";
		Group = "ChatTags";
		Args = {
			{
				Name = "Target";
				Type = "player";
				Description = "Player to disable or enable the tag for";
			},
			{
				Name = "TagKey";
				Type = "chatTagKey";
				Description = "Chat tag to disable";
			},
			{
				Name = "ChatTagDisabled";
				Type = "boolean";
				Description = "Whether or not the tag is disabled";
				Default = true;
			},
		};
	}, function(_context, player, chatTagKey, chatTagDisabled)
		local hasChatTags = self._hasChatTagsBinder:Get(player)

		if not hasChatTags then
			return string.format("%s does not have chat tags", PlayerUtils.formatName(player))
		end

		local chatTag = hasChatTags:GetChatTagByKey(chatTagKey)
		if not chatTag then
			return string.format("%s does not have a chat tag with that key", PlayerUtils.formatName(player))
		end

		chatTag.UserDisabled.Value = chatTagDisabled

		return string.format("Chat tag %q on player %q `UserDisabled` set to %s", chatTagKey, PlayerUtils.formatName(player), tostring(chatTagDisabled))
	end)
end

function ChatProviderCommandService:Destroy()
	self._maid:DoCleaning()
end

return ChatProviderCommandService