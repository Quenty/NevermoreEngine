--- Provides a basis for binders that can be retrieved anywhere
-- @classmod BinderProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local BinderProvider = {}
BinderProvider.ClassName = "BinderProvider"
BinderProvider.__index = BinderProvider

function BinderProvider.new(initMethod)
	local self = setmetatable({}, BinderProvider)

	-- Pretty sure this is a bad idea
	self.BindersAddedPromise = Promise.new()

	self._initMethod = initMethod or error("No initMethod")
	self._afterInit = false
	self._binders = {}

	return self
end

function BinderProvider:Init()
	self:_initMethod(self)
	self.BindersAddedPromise:Resolve(true)
end

function BinderProvider:__index(index)
	if BinderProvider[index] then
		return BinderProvider[index]
	end

	error(("'%s' Not a valid index"):format(tostring(index)))
end

function BinderProvider:AfterInit()
	self._afterInit = true
	for _, binder in pairs(self._binders) do
		binder:Init()
	end
end

function BinderProvider:Get(tagName)
	assert(type(tagName) == "string", "tagName must be a string")
	return rawget(self, tagName)
end

function BinderProvider:Add(binder)
	assert(not self._afterInit, "Already inited")

	assert(not self:Get(binder:GetTag()))
	table.insert(self._binders, binder)
	self[binder:GetTag()] = binder
end

return BinderProvider