--!strict
--[=[
	@class RoduxActionFactory
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local t: any = require("t")

local RoduxActionFactory = {}
RoduxActionFactory.__index = RoduxActionFactory
RoduxActionFactory.ClassName = "RoduxActionFactory"

export type RoduxAction = {
	type: string,
	[any]: any,
}

export type RoduxActionFactory = typeof(setmetatable(
	{} :: {
		_actionName: string,
		_validator: (any) -> (boolean, string?),
	},
	{} :: typeof({ __index = RoduxActionFactory })
))

function RoduxActionFactory.new(actionName: string, typeTable: { [any]: any }?): RoduxActionFactory
	local self: RoduxActionFactory = setmetatable({}, RoduxActionFactory) :: any

	assert(type(actionName) == "string", "Action name must be string, and is required")

	self._actionName = actionName
	self._validator = t.strictInterface(Table.merge({
		type = t.literal(self._actionName),
	}, typeTable or {}))

	return self
end

function RoduxActionFactory.GetType(self: RoduxActionFactory): string
	return self._actionName
end

function RoduxActionFactory.__call(self: RoduxActionFactory, ...: any): RoduxAction
	return self:Create(...)
end

function RoduxActionFactory.CreateDispatcher(
	self: RoduxActionFactory,
	dispatch: (action: RoduxAction) -> ()
): (...any) -> ()
	assert(type(dispatch) == "function", "Bad dispatch")

	return function(...)
		return dispatch(self:Create(...))
	end
end

function RoduxActionFactory.Create(self: RoduxActionFactory, action: { [any]: any }?): RoduxAction
	local actionWithType: RoduxAction
	if action then
		assert(type(action) == "table", "Action must be a table")

		actionWithType = Table.merge(action, {
			type = self._actionName,
		}) :: any
	else
		assert(action == nil, "Action must be nil or table")

		actionWithType = {
			type = self._actionName,
		}
	end

	local ok, err = self._validator(actionWithType)
	if not ok then
		error(err, 3)
	end

	return actionWithType
end

function RoduxActionFactory.Validate(self: RoduxActionFactory, action: any): (boolean, string?)
	return self._validator(action)
end

function RoduxActionFactory.Is(self: RoduxActionFactory, action: RoduxAction): boolean
	return action.type == self._actionName
end

function RoduxActionFactory.IsApplicable(self: RoduxActionFactory, action: RoduxAction): boolean
	if self:Is(action) then
		assert(self:Validate(action))
		return true
	end

	return false
end

return RoduxActionFactory
