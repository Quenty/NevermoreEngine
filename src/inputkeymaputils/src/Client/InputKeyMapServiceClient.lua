--[=[
	Not required to be initialized
	@class InputKeyMapServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local InputKeyMapServiceClient = {}

function InputKeyMapServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._providers = {}
end

function InputKeyMapServiceClient:RegisterProvider(provider)
	assert(provider, "Bad provider")
	assert(self._providers, "Not initialized")

	local providerName = provider:GetProviderName()
	if self._providers[providerName] then
		error(("Already have a provider with name %q"):format(providerName))
	end

	self._providers[providerName] = provider
end

function InputKeyMapServiceClient:GetProvider(providerName)
	assert(type(providerName) == "string", "Bad providerName")

	return self._providers[providerName]
end

-- function InputKeyMapServiceClient:ObserveInputKeyMapList(providerName, inputKeyMapListName)
-- 	assert(type(providerName) == "string", "Bad providerName")
-- 	assert(type(inputKeyMapListName) == "string", "Bad inputKeyMapListName")

-- end

function InputKeyMapServiceClient:FindInputKeyMapList(providerName, inputKeyMapListName)
	assert(type(providerName) == "string", "Bad providerName")
	assert(type(inputKeyMapListName) == "string", "Bad inputKeyMapListName")

	if not RunService:IsRunning() then
		return nil
	end

	assert(self._providers, "Not initialized")
	for _, provider in pairs(self._providers) do
		if provider:GetProviderName() == providerName then
			local found = provider:FindInputKeyMapList(inputKeyMapListName)
			if found then
				return found
			end
		end
	end

	return nil
end



return InputKeyMapServiceClient