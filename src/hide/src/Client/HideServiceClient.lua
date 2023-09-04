--[=[
	@class HideServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local HideServiceClient = {}
HideServiceClient.ServiceName = "HideServiceClient"

function HideServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("HideClient"))
end

return HideServiceClient