---
-- @classmod RoduxActionFactory
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")
local t = require("t")

local RoduxActionFactory = {}
RoduxActionFactory.__index = RoduxActionFactory
RoduxActionFactory.ClassName = "RoduxActionFactory"

function RoduxActionFactory.new(actionName, typeTable)
	local self = setmetatable({}, RoduxActionFactory)

	typeTable = typeTable or {}

	self._actionName = actionName or error("No actionName")
	self._validator = t.strictInterface(
		Table.Merge({
			type = t.literal(actionName),
		}, typeTable))

	return self
end

function RoduxActionFactory:__call(...)
	return self:Create(...)
end

function RoduxActionFactory:Create(action)
	local actionWithType
	if action then
		assert(type(action) == "table", "Action must be a table")

		actionWithType = Table.Merge(action, {
			type = self._actionName;
		})
	else
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

function RoduxActionFactory:Is(action)
	return action.type == self._actionName
end

function RoduxActionFactory:IsApplicable(action)
	if self:Is(action) then
		assert(self:Validate(action))
		return true
	end

	return false
end

return RoduxActionFactory