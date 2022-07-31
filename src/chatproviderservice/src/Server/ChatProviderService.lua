--[=[
	Wrapper around Roblox chat service on the server
	@class ChatProviderService
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Maid = require("Maid")

local ChatProviderService = {}

--[=[
	Sets the speaker's tag (by speaker name)

	@param speakerName string
	@param tags { ChatTagData }
]=]
function ChatProviderService:PromiseSetSpeakerTags(speakerName, tags)
	assert(type(speakerName) == "string", "Bad speakerName")
	assert(type(tags) == "table", "Bad tags")

	return self:_promiseSpeaker(speakerName)
		:Then(function(speaker)
			speaker:SetExtraData("Tags", tags)
		end, function(err)
			warn("[ChatProviderService.PromiseSetTags] - No speaker found", err)
		end)
end

function ChatProviderService:_getChatServiceAsync()
	if self._chatService then
		return self._chatService
	end

	local chatService = require(ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))
	self._chatService = chatService or error("No chatService retrieved")

	return self._chatService
end

function ChatProviderService:_promiseChatService()
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


function ChatProviderService:_promiseSpeaker(speakerName)
	assert(type(speakerName) == "string", "Bad speakerName")

	return self:_promiseChatService():Then(function(chatService)
		local foundSpeaker = chatService:GetSpeaker(speakerName)
		if foundSpeaker then
			return foundSpeaker
		end

		local promise = Promise.new()
		local maid = Maid.new()

		-- Listen to speaker added
		maid:GiveTask(chatService.SpeakerAdded:Connect(function(speakerAddedName)
			if speakerName == speakerAddedName then
				local speaker = chatService:GetSpeaker(speakerName)
				if not speaker then
					warn("[ChatProviderService] - Speaker added, but no speaker added")
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