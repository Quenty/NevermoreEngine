--!strict
--[=[
	Groups binders together into a list, and allows binders to be dynamically
	added or removed.

	Also allows their interface to be validated using a validation function.
	This ensures that all added objects are the same type, so they can be used
	for dynamic interactions.

	@class BinderGroup
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Signal = require("Signal")

local BinderGroup = {}
BinderGroup.ClassName = "BinderGroup"
BinderGroup.__index = BinderGroup

export type BinderConstructorValidator = (constructor: Binder.BinderConstructor<any>) -> boolean

export type BinderGroup = typeof(setmetatable(
	{} :: {
		_binders: { Binder.Binder<any> },
		_bindersByTag: { [string]: Binder.Binder<any> },
		_validateConstructor: BinderConstructorValidator?,
		BinderAdded: Signal.Signal<Binder.Binder<any>>,
	},
	{} :: typeof({ __index = BinderGroup })
))
--[=[
	Constructs a new BinderGroup

	@param binders { Binder<T> } -- A list of binders that
	@param validateConstructor (constructor: any) -> boolean -- Validates a binder matches T
	@return BinderGroup<T>
]=]
function BinderGroup.new(binders: { Binder.Binder<any> }, validateConstructor: BinderConstructorValidator?): BinderGroup
	local self: BinderGroup = setmetatable({} :: any, BinderGroup)

	self._binders = {}
	self._bindersByTag = {}
	self._validateConstructor = validateConstructor

	self.BinderAdded = Signal.new() :: any

	self:AddList(binders)

	return self
end

--[=[
	Adds a list of binders to the group.

	@param binders { Binder<T> }
]=]
function BinderGroup.AddList(self: BinderGroup, binders: { Binder.Binder<any> })
	assert(type(binders) == "table", "Bad binders")

	-- Assume to be using osyris's typechecking library,
	-- we have an optional constructor to validate binder classes.
	for _, binder in binders do
		self:Add(binder :: any)
	end
end

--[=[
	Adds the specific binder to the list

	@param binder Binder<T>
]=]
function BinderGroup.Add(self: BinderGroup, binder: Binder.Binder<any>)
	assert(Binder.isBinder(binder), "Binder is not a binder")

	if self._validateConstructor then
		assert(self._validateConstructor(binder:GetConstructor()))
	end

	local tag = binder:GetTag()
	if self._bindersByTag[tag] then
		warn("[BinderGroup.Add] - Binder with tag %q already added. Adding again.")
	end

	self._bindersByTag[tag] = binder
	table.insert(self._binders, binder)

	self.BinderAdded:Fire(binder)
end

--[=[
	Returns a list of binders.

	:::warning
	Do not modify the list of binders returned here
	:::

	@return { Binder.Binder<any> }
]=]
function BinderGroup.GetBinders(self: BinderGroup): { Binder.Binder<any> }
	assert(self._binders, "No self._binders")

	return self._binders
end

return BinderGroup
