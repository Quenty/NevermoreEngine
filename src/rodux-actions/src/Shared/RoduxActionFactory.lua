--[=[
	@class RoduxActionFactory
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local t = require("t")

local RoduxActionFactory = {}
RoduxActionFactory.__index = RoduxActionFactory
RoduxActionFactory.ClassName = "RoduxActionFactory"

function RoduxActionFactory.new(actionName, typeTable)
	local self = setmetatable({}, RoduxActionFactory)

	typeTable = typeTable or {}

	assert(type(actionName) == "string", "Action name must be string, and is required")

	self._actionName = actionName
	self._validator = t.strictInterface(
		Table.merge({
			type = t.literal(self._actionName),
		}, typeTable))

	return self
end

function RoduxActionFactory:GetType()
	return self._actionName
end

function RoduxActionFactory:__call(...)
	return self:Create(...)
end

function RoduxActionFactory:CreateDispatcher(dispatch: () -> ())
	assert(type(dispatch) == "function", "Bad dispatch")

	return function(...)
		return dispatch(self:Create(...))
	end
end

function RoduxActionFactory:Create(action)
	local actionWithType
	if action then
		assert(type(action) == "table", "Action must be a table")

		actionWithType = Table.merge(action, {
			type = self._actionName;
		})
	else
		assert(action == nil, "Action must be nil or table")

		actionWithType = {
			type = self._actionName;
		}
	end

	local ok, err = self._validator(actionWithType)
	if not ok then
		error(err, 3)
	end

	return actionWithType
end

function RoduxActionFactory:Validate(action)
	return self._validator(action)
end

function RoduxActionFactory:Is(action): boolean
	return action.type == self._actionName
end

function RoduxActionFactory:IsApplicable(action): boolean
	if self:Is(action) then
		assert(self:Validate(action))
		return true
	end

	return false
end

return RoduxActionFactory