--[=[
	@class ChatProviderCommandService
]=]

local require = require(script.Parent.loader).load(script)

local PlayerUtils = require("PlayerUtils")
local ChatTagDataUtils = require("ChatTagDataUtils")

local ChatProviderCommandService = {}
ChatProviderCommandService.ServiceName = "ChatProviderCommandService"

function ChatProviderCommandService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._chatProviderService = self._serviceBag:GetService(require("ChatProviderService"))
end

function ChatProviderCommandService:Start()
	self:_registerCommands()
end

function ChatProviderCommandService:_registerCommands()
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
end

return ChatProviderCommandService