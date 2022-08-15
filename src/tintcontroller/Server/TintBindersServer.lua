--[=[
	See [TintBindersClient] for usage.

	@server
	@class TintBindersServer
]=]
local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
--[=[
	@prop TintController Binder<TintController>
	@within TintBindersServer
]=]
	self:Add(Binder.new("TintController", require("TintController"), serviceBag))
end)