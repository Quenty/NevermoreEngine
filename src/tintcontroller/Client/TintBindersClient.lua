--[=[
	Initializes the tinting system on the client.

	```lua
	local TintBindersClient = require("TintBindersClient")
	local TintControllerUtils = require("TintControllerUtils")
	local ServiceBag = require("ServiceBag")

	local serviceBag = ServiceBag.new()
	serviceBag:GetService(TintBindersClient)

	serviceBag:Init()
	serviceBag:Start()

	-- 'workspace.Model', and all of its descendants tagged with `Tint`, will change color.
	TintBindersClient:BindClient(workspace.Model)
	TintControllerUtils.setTint(workspace.Model, Color3.new(1, 1, 1))
	TintControllerUtils.setTint(workspace.Model, BrickColor.random())
	TintControllerUtils.setTint(workspace.Model, "Pastel light blue")
	TintControllerUtils.setTint(workspace.Model, {255, 0, 0})
	```

	@client
	@class TintBindersClient
]=]
local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
--[=[
	@prop TintController Binder<TintControllerClient>
	@within TintBindersClient
]=]
	self:Add(Binder.new("TintController", require("TintControllerClient"), serviceBag))
end)