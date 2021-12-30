--[=[
	Initializes the hiding system on the server. You can do this on the client
	if you need to query for raycasting. See [HideBindersClient].

	```lua
	local HideBindersServer = require("HideBindersServer")
	local ServiceBag = require("ServiceBag")

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(HideBindersServer)

	serviceBag:Init()
	serviceBag:Start()
	```

	@server
	@class HideBindersServer
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
--[=[
	@prop Hide Binder<Hide>
	@within HideBindersServer
]=]
	self:Add(Binder.new("Hide", require("Hide"), serviceBag))
end)