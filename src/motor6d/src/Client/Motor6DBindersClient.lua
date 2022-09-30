--[=[
	@class Motor6DBindersClient
]=]

local require = require(script.Parent.loader).load(script)

local BinderProvider = require("BinderProvider")
local Binder = require("Binder")

return BinderProvider.new(function(self, serviceBag)
	self:Add(Binder.new("Motor6DStack", require("Motor6DStackClient"), serviceBag))
end)