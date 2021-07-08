--- Provides a basis for binders that can be retrieved anywhere
-- @classmod BinderProvider

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Promise = require("Promise")

local BinderProvider = {}
BinderProvider.ClassName = "BinderProvider"
BinderProvider.__index = BinderProvider

function BinderProvider.new(initMethod)
	local self = setmetatable({}, BinderProvider)

	-- Pretty sure this is a bad idea
	self._bindersAddedPromise = Promise.new()
	self._startPromise = Promise.new()

	self._initMethod = initMethod or error("No initMethod")

	self._initialized = false
	self._started = false
	self._binders = {}

	return self
end

--- Retrieves whether or not its a binder provider
-- @param value
-- @return true or false, whether or not it is a value
function BinderProvider.isBinderProvider(value)
	return type(value) == "table" and value.ClassName == "BinderProvider"
end

function BinderProvider:PromiseBinder(binderName)
	if self._bindersAddedPromise:IsFulfilled() then
		local binder = self:Get(binderName)
		if binder then
			return Promise.resolved(binder)
		else
			return Promise.rejected()
		end
	end

	return self._bindersAddedPromise
		:Then(function()
			local binder = self:Get(binderName)
			if binder then
				return binder
			else
				return Promise.rejected()
			end
		end)
end

-- Initializes itself and all binders
function BinderProvider:Init()
	assert(not self._initialized, "Already initialized")

	self._initialized = true
	self:_initMethod(self)
	self._bindersAddedPromise:Resolve()
end

function BinderProvider:PromiseBindersAdded()
	return self._bindersAddedPromise
end

function BinderProvider:PromiseBindersStarted()
	return self._startPromise
end

-- Starts all of the binders
function BinderProvider:Start()
	assert(self._initialized, "Not initialized")
	assert(not self._started, "Already started")

	self._started = true
	for _, binder in pairs(self._binders) do
		binder:Start()
	end

	self._startPromise:Resolve()
end

function BinderProvider:__index(index)
	if BinderProvider[index] then
		return BinderProvider[index]
	end

	error(("%q Not a valid index"):format(tostring(index)))
end

function BinderProvider:Get(tagName)
	assert(type(tagName) == "string", "tagName must be a string")
	return rawget(self, tagName)
end

function BinderProvider:Add(binder)
	assert(not self._started, "Already inited")
	assert(not self:Get(binder:GetTag()), "Binder already exists")

	table.insert(self._binders, binder)
	self[binder:GetTag()] = binder
end

return BinderProvider