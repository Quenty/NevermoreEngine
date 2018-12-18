--- Extends PartTouchingCalculator with generic binder stuff
-- @classmod BinderTouchingCalculator
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local PartTouchingCalculator = require("PartTouchingCalculator")
local BinderUtil = require("BinderUtil")

local BinderTouchingCalculator = setmetatable({}, PartTouchingCalculator)
BinderTouchingCalculator.ClassName = "BinderTouchingCalculator"
BinderTouchingCalculator.__index = BinderTouchingCalculator

function BinderTouchingCalculator.new()
	local self = setmetatable(PartTouchingCalculator.new(), BinderTouchingCalculator)

	return self
end

function BinderTouchingCalculator:GetTouchingClass(binder, touchingList)
	local touching = {}

	for _, part in pairs(touchingList) do
		local class = BinderUtil.FindFirstAncestor(self._propBinder)
		if not touching[class] then

			touching[class] = {
				Class = class;
				Touching = { part };
			}
		else
			table.insert(touching[class].Touching, part)
		end
	end

	local list = {}
	for _, data in pairs(touching) do
		table.insert(list, data)
	end

	return list
end

return BinderTouchingCalculator