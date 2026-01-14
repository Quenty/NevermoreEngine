--!strict
--[=[
	@class {{gameNameProper}}ServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local {{gameNameProper}}ServiceClient = {}
{{gameNameProper}}ServiceClient.ServiceName = "{{gameNameProper}}ServiceClient"

export type {{gameNameProper}}ServiceClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
		},
		{} :: typeof({ __index = {{gameNameProper}}ServiceClient })
	))

function {{gameNameProper}}ServiceClient.Init(self: {{gameNameProper}}ServiceClient,serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("{{gameNameProper}}Translator"))
end

return {{gameNameProper}}ServiceClient
