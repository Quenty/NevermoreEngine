--!strict
--[=[
	@class {{gameNameProper}}Service
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local {{gameNameProper}}Service = {}
{{gameNameProper}}Service.ServiceName = "{{gameNameProper}}Service"

export type {{gameNameProper}}Service =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
		},
		{} :: typeof({ __index = {{gameNameProper}}Service })
	))

function {{gameNameProper}}Service.Init(self: {{gameNameProper}}Service, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("{{gameNameProper}}Translator"))
end

return {{gameNameProper}}Service
