--[=[
	@class {{gameNameProper}}Service
]=]

local require = require(script.Parent.loader).load(script)

local {{gameNameProper}}Service = {}
{{gameNameProper}}Service.ServiceName = "{{gameNameProper}}Service"

function {{gameNameProper}}Service:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("{{gameNameProper}}Translator"))
end

return {{gameNameProper}}Service