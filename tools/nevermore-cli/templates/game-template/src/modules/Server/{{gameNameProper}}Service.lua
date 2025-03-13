--[=[
	@class {{gameNameProper}}Service
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local {{gameNameProper}}Service = {}
{{gameNameProper}}Service.ServiceName = "{{gameNameProper}}Service"

function {{gameNameProper}}Service:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("{{gameNameProper}}Translator"))
end

return {{gameNameProper}}Service