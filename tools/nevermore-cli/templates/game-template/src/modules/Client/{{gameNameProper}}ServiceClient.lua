--[=[
	@class {{gameNameProper}}ServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local {{gameNameProper}}ServiceClient = {}
{{gameNameProper}}ServiceClient.ServiceName = "{{gameNameProper}}ServiceClient"

function {{gameNameProper}}ServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("{{gameNameProper}}Translator"))
end

return {{gameNameProper}}ServiceClient