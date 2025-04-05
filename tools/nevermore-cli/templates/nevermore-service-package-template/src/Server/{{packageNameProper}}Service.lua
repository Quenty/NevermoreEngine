--[=[
	@class {{packageNameProper}}Service
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local {{packageNameProper}}Service = {}
{{packageNameProper}}Service.ServiceName = "{{packageNameProper}}Service"

function {{packageNameProper}}Service:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return {{packageNameProper}}Service