--[=[
	@class {{packageNameProper}}Service
]=]

local require = require(script.Parent.loader).load(script)

local {{packageNameProper}}Service = {}
{{packageNameProper}}Service.ServiceName = "{{packageNameProper}}Service"

function {{packageNameProper}}Service:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")


end

return {{packageNameProper}}Service