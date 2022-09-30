--[=[
	@class Motor6DService
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DService = {}
Motor6DService.ServiceName = "Motor6DService"

function Motor6DService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("Motor6DBindersServer"))
end

return Motor6DService