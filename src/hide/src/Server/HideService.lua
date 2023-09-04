--[=[
	@class HideService
]=]

local require = require(script.Parent.loader).load(script)

local HideService = {}
HideService.ServiceName = "HideService"

function HideService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("Hide"))
end

return HideService