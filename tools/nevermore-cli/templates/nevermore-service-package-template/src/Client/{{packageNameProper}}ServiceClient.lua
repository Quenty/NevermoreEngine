--[=[
	@class {{packageNameProper}}ServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local _ServiceBag = require("ServiceBag")

local {{packageNameProper}}ServiceClient = {}
{{packageNameProper}}ServiceClient.ServiceName = "{{packageNameProper}}ServiceClient"

function {{packageNameProper}}ServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return {{packageNameProper}}ServiceClient