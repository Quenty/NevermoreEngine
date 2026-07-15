--!strict
--[=[
	Provides a basis for binders that can be retrieved anywhere
	@class BinderProvider
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Maid = require("Maid")
local Promise = require("Promise")

local BinderProvider = {}
BinderProvider.ClassName = "BinderProvider"
BinderProvider.ServiceName = "BinderProvider"
BinderProvider.__index = BinderProvider

export type BinderProvider = typeof(setmetatable(
	{} :: {
		ServiceName: string,
		_initMethod: (self: BinderProvider, ...any) -> (),
		_initialized: boolean,
		_destroyed: boolean,
		_started: boolean,
		_maid: Maid.Maid,
		_binders: { any },
		_bindersAddedPromise: Promise.Promise<()>,
		_startPromise: Promise.Promise<()>,
	},
	{} :: typeof({ __index = BinderProvider })
))

--[=[
	Constructs a new BinderProvider.

	:::tip
	Don't use this! You can retrieve binders from the service bag directly
	:::

	```lua
	local ServiceBag = require("ServiceBag")

	local serviceBag = ServiceBag.new()

	-- Usually in a separate file!
	local binderProvider = BinderProvider.new("BirdBinders", function(self, serviceBag: ServiceBag.ServiceBag)
		self:Add(Binder.new("MyClass", require("MyClass"), serviceBag))
	end)

	-- Retrieve binders
	local binders = serviceBag:GetService(binderProvider)

	-- Runs the game (including binders)
	serviceBag:Init()
	serviceBag:Start()
	```

	@param serviceName string -- Name of the service (used for memory tracking)
	@param initMethod (self, serviceBag: ServiceBag)
	@return BinderProvider
]=]
function BinderProvider.new(serviceName: string, initMethod: ((self: BinderProvider, ...any) -> ())?): BinderProvider
	local self: BinderProvider = setmetatable({} :: any, BinderProvider)

	if type(serviceName) == "string" then
		self.ServiceName = serviceName
	else
		-- Backwords compatibility (for now)
		if type(serviceName) == "function" and initMethod == nil then
			warn(
				"[BinderProvider] - Missing serviceName for binder provider. Please pass in a service name as the first argument."
			)
			initMethod = serviceName
		else
			error("Bad serviceName")
		end
	end

	self._initMethod = initMethod or error("No initMethod")
	self._initialized = false
	self._destroyed = false
	self._started = false

	return self
end

--[=[
	Retrieves whether or not its a binder provider
	@param value any
	@return boolean -- True if it is a binder provider
]=]
function BinderProvider.isBinderProvider(value: any): boolean
	return type(value) == "table" and value.ClassName == "BinderProvider"
end

--[=[
	Resolves to the given binder given the binderName.

	@param binderName string
	@return Promise<Binder<T>>
]=]
function BinderProvider.PromiseBinder(self: BinderProvider, binderName: string): Promise.Promise<Binder.Binder<any>>
	if self._bindersAddedPromise:IsFulfilled() then
		local binder = self:Get(binderName)
		if binder then
			return Promise.resolved(binder)
		else
			return Promise.rejected()
		end
	end

	return self._bindersAddedPromise:Then(function()
		local binder = self:Get(binderName)
		if binder then
			return binder
		else
			return Promise.rejected()
		end
	end) :: any
end

--[=[
	Initializes itself and all binders

	@param ... ServiceBag | any
]=]
function BinderProvider.Init(self: BinderProvider, ...: any): ()
	assert(not self._initialized, "Already initialized")

	self._maid = Maid.new()

	self._binders = {}
	self._initialized = true

	-- Pretty sure this is a bad idea
	self._bindersAddedPromise = self._maid:Add(Promise.new())
	self._startPromise = self._maid:Add(Promise.new())

	self._initMethod(self, ...)

	for _, binder in self._binders do
		binder:Init(...)
	end

	self._bindersAddedPromise:Resolve()
end

--[=[
	Returns a promise that will resolve once all binders are added.

	@return Promise
]=]
function BinderProvider.PromiseBindersAdded(self: BinderProvider): Promise.Promise<()>
	return assert(self._bindersAddedPromise, "Be sure to require via serviceBag")
end

--[=[
	Returns a promise that will resolve once all binders are started.

	@return Promise
]=]
function BinderProvider.PromiseBindersStarted(self: BinderProvider): Promise.Promise<()>
	return assert(self._startPromise, "Be sure to require via serviceBag")
end

--[=[
	Starts all of the binders.
]=]
function BinderProvider.Start(self: BinderProvider): ()
	assert(self._initialized, "Not initialized")
	assert(not self._started, "Already started")

	self._started = true
	for _, binder in self._binders do
		binder:Start()
	end

	self._startPromise:Resolve()
end
(BinderProvider :: any).__index = function(self, index)
	if BinderProvider[index] then
		return BinderProvider[index]
	end

	if rawget(self, "_destroyed") then
		error(string.format("BinderProvider is destroyed. Cannot index %q", tostring(index)))
	end

	error(string.format("%q Not a valid binder", tostring(index)))
end

--[=[
	Retrieves a binder given a tagName

	@param tagName string
	@return Binder<T>?
]=]
function BinderProvider.Get(self: BinderProvider, tagName: string): Binder.Binder<any>?
	assert(type(tagName) == "string", "Bad tagName")
	return rawget(self :: any, tagName)
end

--[=[
	Adds a binder given a tag name.

	@param binder Binder<T>
]=]
function BinderProvider.Add(self: BinderProvider, binder: Binder.Binder<any>): ()
	assert(not self._started, "Already inited")
	assert(not self:Get(binder:GetTag()), "Binder already exists")

	self._maid:GiveTask(binder)

	table.insert(self._binders, binder);
	(self :: any)[binder:GetTag()] = binder
end

function BinderProvider.Destroy(self: BinderProvider): ()
	self._destroyed = true

	local binders = rawget(self :: any, "_binders")
	rawset(self :: any, "_binders", nil)

	if binders then
		for _, item in binders do
			rawset(self :: any, item:GetTag(), nil)
		end
	end

	local maid = rawget(self :: any, "_maid")
	rawset(self :: any, "_maid", nil)

	if maid then
		maid:DoCleaning()
		maid = nil
	end
end

return BinderProvider
