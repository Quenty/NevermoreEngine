--[=[
	@class Motor6DServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DServiceClient = {}
Motor6DServiceClient.ServiceName = "Motor6DServiceClient"

function Motor6DServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("Motor6DBindersClient"))
end

return Motor6DServiceClient