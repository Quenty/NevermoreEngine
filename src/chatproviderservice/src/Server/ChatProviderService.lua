--!strict
--[=[
	Wrapper around Roblox chat service on the server
	@class ChatProviderService
]=]

local require = require(script.Parent.loader).load(script)

local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Binder = require("Binder")
local Brio = require("Brio")
local ChatTagDataUtils = require("ChatTagDataUtils")
local HasChatTags = require("HasChatTags")
local LocalizedTextUtils = require("LocalizedTextUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PermissionLevel = require("PermissionLevel")
local PreferredParentUtils = require("PreferredParentUtils")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

local ChatProviderService = {}
ChatProviderService.ServiceName = "ChatProviderService"

export type ChatProviderService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		MessageIncoming: Signal.Signal<any>,
		_hasChatTagsBinder: Binder.Binder<HasChatTags.HasChatTags>,
		_chatService: any, -- legacy ChatServiceRunner.ChatService (untyped)
		_chatServicePromise: any, -- Promise.Promise<any>
	},
	{} :: typeof({ __index = ChatProviderService })
))

function ChatProviderService.Init(self: ChatProviderService, serviceBag: ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- State
	self.MessageIncoming = self._maid:Add(Signal.new())

	-- External
	self._serviceBag:GetService(require("CmdrService"))
	self._serviceBag:GetService(require("PermissionService"))
	self._serviceBag:GetService(require("PlayerDataStoreService"))

	-- Internal
	self._serviceBag:GetService((require :: any)("ChatProviderCommandService"))
	self._serviceBag:GetService(require("ChatProviderTranslator"))

	-- Binders
	self._serviceBag:GetService(require("ChatTag"))
	self._hasChatTagsBinder = self._serviceBag:GetService(HasChatTags)

	-- note: normally we don't expose default API surfaces like this with defaults, however, because this only affects developers and this
	-- tends to significantly improve feedback we're leaving this default configuration in place.
	self:SetDeveloperTag(ChatTagDataUtils.createChatTagData({
		TagText = "(dev)",
		TagLocalizedText = LocalizedTextUtils.create("chatTags.dev"),
		TagPriority = 15,
		TagColor = Color3.fromRGB(245, 163, 27),
	}))
	self:SetAdminTag(ChatTagDataUtils.createChatTagData({
		TagText = "(mod)",
		TagLocalizedText = LocalizedTextUtils.create("chatTags.mod"),
		TagPriority = 10,
		TagColor = Color3.fromRGB(78, 205, 196),
	}))
end

function ChatProviderService.AddChatCommand(_self: ChatProviderService, textChatCommand: TextChatCommand)
	assert(typeof(textChatCommand) == "Instance", "Bad textChatCommand")

	textChatCommand.Parent = PreferredParentUtils.getPreferredParent(TextChatService, "ChatProviderCommands")
end

--[=[
	Sets the developer chat tag

	@param chatTagData ChatTagData?
	@return Maid
]=]
function ChatProviderService.SetDeveloperTag(self: ChatProviderService, chatTagData: ChatTagDataUtils.ChatTagData?)
	assert(ChatTagDataUtils.isChatTagData(chatTagData) or chatTagData == nil, "Bad chatTagData")

	if chatTagData then
		local permissionService: any = self._serviceBag:GetService(require("PermissionService"))
		local observeBrio = permissionService:ObservePermissionedPlayersBrio(PermissionLevel.CREATOR)

		self._maid._developer = self:_addObservablePlayerTag(observeBrio, chatTagData)
	else
		self._maid._developer = nil
	end
end

--[=[
	Sets the admin tag to the game

	@param chatTagData ChatTagData?
	@return Maid
]=]
function ChatProviderService.SetAdminTag(self: ChatProviderService, chatTagData: ChatTagDataUtils.ChatTagData?)
	assert(ChatTagDataUtils.isChatTagData(chatTagData) or chatTagData == nil, "Bad chatTagData")

	if chatTagData then
		local permissionService: any = self._serviceBag:GetService(require("PermissionService"))
		local observeBrio = permissionService:ObservePermissionedPlayersBrio(PermissionLevel.ADMIN):Pipe({
			RxBrioUtils.flatMapBrio(function(player: Player)
				return Rx.fromPromise(permissionService:PromiseIsPermissionLevel(player, PermissionLevel.CREATOR))
					:Pipe({
						Rx.switchMap(function(isAlsoCreator): any
							if not isAlsoCreator then
								return Rx.of(player)
							else
								return Rx.EMPTY
							end
						end) :: any,
					})
			end) :: any,
		})

		self._maid._admin = self:_addObservablePlayerTag(observeBrio, chatTagData)
	else
		self._maid._admin = nil
	end
end

function ChatProviderService._addObservablePlayerTag(
	self: ChatProviderService,
	observePlayersBrio: Observable.Observable<Brio.Brio<Player>>,
	chatTagData: ChatTagDataUtils.ChatTagData
): Maid.Maid
	assert(ChatTagDataUtils.isChatTagData(chatTagData), "Bad chatTagData")

	local topMaid = Maid.new()
	self._maid[topMaid] = topMaid
	topMaid:GiveTask(function()
		self._maid[topMaid] = nil
	end)

	topMaid:GiveTask(observePlayersBrio:Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local player = brio:GetValue()

		maid:GivePromise(self:PromiseAddChatTag(player, chatTagData)):Then(function(chatTag)
			maid:GiveTask(chatTag)
		end)
	end))

	return topMaid
end

--[=[
	Promises to add a chat tag to the player

	@param player Player
	@param chatTagData ChatTagData
	@return Promise<Instance>
]=]
function ChatProviderService.PromiseAddChatTag(
	self: ChatProviderService,
	player: Player,
	chatTagData: ChatTagDataUtils.ChatTagData
): Promise.Promise<Instance>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(ChatTagDataUtils.isChatTagData(chatTagData), "Bad chatTagData")

	local hasChatTagBinder = self._serviceBag:GetService(HasChatTags)

	return hasChatTagBinder:Promise(player):Then(function(hasChatTag)
		return hasChatTag:AddChatTag(chatTagData)
	end)
end

--[=[
	Clears the player's chat chatTagData.

	@param player Player
]=]
function ChatProviderService.ClearChatTags(self: ChatProviderService, player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local hasChatTagBinder = self._serviceBag:GetService(HasChatTags)
	local hasChatTags = hasChatTagBinder:Get(player)

	if hasChatTags then
		hasChatTags:ClearTags()
	end
end

--[=[
	Sets the speaker's tag (by speaker name)

	@param speakerName string
	@param chatTagDataList { ChatTagData }
	@return Promise
]=]
function ChatProviderService.PromiseSetSpeakerTags(
	self: ChatProviderService,
	speakerName: string,
	chatTagDataList: { ChatTagDataUtils.ChatTagData }
): Promise.Promise<()>
	assert(type(speakerName) == "string", "Bad speakerName")
	assert(ChatTagDataUtils.isChatTagDataList(chatTagDataList))

	return self:_promiseSpeaker(speakerName):Then(function(speaker)
		if not speaker then
			return
		end

		speaker:SetExtraData("Tags", chatTagDataList)
	end, function(err)
		warn("[ChatProviderService.PromiseSetTags] - No speaker found", err)
	end)
end

function ChatProviderService._getChatServiceAsync(self: ChatProviderService): any
	if self._chatService then
		return self._chatService
	end

	local chatServiceRunner = ServerScriptService:WaitForChild("ChatServiceRunner", 5)
	if not chatServiceRunner then
		-- Presumably we have upgraded to the new chat.
		return nil
	end

	local chatService = (require :: any)(chatServiceRunner:WaitForChild("ChatService"))
	self._chatService = chatService or error("No chatService retrieved")

	return self._chatService
end

function ChatProviderService._promiseChatService(self: ChatProviderService): Promise.Promise<any>
	if self._chatService then
		return Promise.resolved(self._chatService)
	end

	if self._chatServicePromise then
		return Promise.resolved(self._chatServicePromise)
	end

	self._chatServicePromise = Promise.defer(function(resolve, _reject)
		resolve(self:_getChatServiceAsync())
	end)

	return Promise.resolved(self._chatServicePromise)
end

function ChatProviderService._promiseSpeaker(self: ChatProviderService, speakerName: string): Promise.Promise<any>
	assert(type(speakerName) == "string", "Bad speakerName")

	return self:_promiseChatService():Then(function(chatService)
		if not chatService then
			return nil
		end

		local foundSpeaker = chatService:GetSpeaker(speakerName)
		if foundSpeaker then
			return foundSpeaker
		end

		local promise = Promise.new()
		local maid = Maid.new()

		-- TODO: Avoid memory leaking
		maid:GiveTask(task.delay(5, function()
			warn("[ChatProviderService._promiseSpeaker] - Infinite yield possible for speaker")
		end))

		-- Listen to speaker added
		maid:GiveTask(chatService.SpeakerAdded:Connect(function(speakerAddedName)
			if speakerName == speakerAddedName then
				local speaker = chatService:GetSpeaker(speakerName)
				if not speaker then
					warn("[ChatProviderService._promiseSpeaker] - Speaker added, but no speaker added")
					promise:Reject("Speaker added, but no speaker added")
				else
					promise:Resolve(speaker)
				end
			end
		end))

		promise:Finally(function()
			maid:DoCleaning()
		end)

		return promise
	end)
end

return ChatProviderService
