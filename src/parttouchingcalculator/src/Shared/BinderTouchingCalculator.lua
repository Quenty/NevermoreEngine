--[=[
	Extends PartTouchingCalculator with generic binder stuff
	@class BinderTouchingCalculator
]=]

local require = require(script.Parent.loader).load(script)

local PartTouchingCalculator = require("PartTouchingCalculator")
local BinderUtils = require("BinderUtils")

local BinderTouchingCalculator = setmetatable({}, PartTouchingCalculator)
BinderTouchingCalculator.ClassName = "BinderTouchingCalculator"
BinderTouchingCalculator.__index = BinderTouchingCalculator

function BinderTouchingCalculator.new()
	local self = setmetatable(PartTouchingCalculator.new(), BinderTouchingCalculator)

	return self
end

function BinderTouchingCalculator:GetTouchingClass(binder, touchingList, ignoreObject)
	local touching = {}

	for _, part in touchingList do
		local object = BinderUtils.findFirstAncestor(binder, part)
		if object then
			if not touching[object] then
				touching[object] = {
					Object = object,
					Touching = {
						part,
					},
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
	for _, data in touching do
		table.insert(list, data)
	end

	return list
end

return BinderTouchingCalculator