--[=[
	Initializes the hiding system on the client. See [HideBindersServer].

	```lua
	local HideBindersClient = require("HideBindersClient")
	local ServiceBag = require("ServiceBag")

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(HideBindersClient)

	serviceBag:Init()
	serviceBag:Start()
	```

	@client
	@class HideBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
--[=[
	@prop Hide Binder<HideClient>
	@within HideBindersClient
]=]
	self:Add(Binder.new("Hide", require("HideClient"), serviceBag))
end)