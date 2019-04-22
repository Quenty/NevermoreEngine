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

function BinderTouchingCalculator:GetTouchingClass(binder, touchingList, ignoreObject)
	local touching = {}

	for _, part in pairs(touchingList) do
		local object = BinderUtil.findFirstAncestor(binder, part)
		if object then
			if not touching[object] then
				touching[object] = {
					Object = object;
					Touching = {
						part
					};
				}
			else
				table.insert(touching[object].Touching, part)
			end
		end
	end

	if ignoreObject then
		touching[ignoreObject] = nil
	end

	local list = {}
	for _, data in pairs(touching) do
		table.insert(list, data)
	end

	return list
end

return BinderTouchingCalculator