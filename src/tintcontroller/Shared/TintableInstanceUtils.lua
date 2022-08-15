--[=[
	Identifies and modifies tintable instances (most instances with a Color3 property).
	This is a generic utility with no relation to [TintController] or its associated tags.

	@class TintableInstanceUtils
]=]

local TintableInstanceUtils = {}

--[=[
	Given an adornee, find the name of a Color3 property we can modify.

	@within TintableInstanceUtils
	@private
	@param adornee Instance
	@return string
]=]
local function identifyTintProperty(adornee: Instance)
	if
		adornee:IsA("BasePart")
		or adornee:IsA("WrapTarget")
		or adornee:IsA("WrapLayer")
		or adornee:IsA("Constraint")
	then
		return "Color"
	elseif adornee:IsA("Decal") or adornee:IsA("GuiBase3d") then
		return "Color3"
	elseif adornee:IsA("ImageLabel") then
		return "ImageColor3"
	end
end

--[=[
	Given an adornee, find out if we can assign its tint.

	@param adornee Instance
	@return boolean
]=]
function TintableInstanceUtils.isTintable(adornee: Instance)
	return identifyTintProperty(adornee) ~= nil
end

--[=[
	Set an adornee's tint property.

	@param adornee Instance
]=]
function TintableInstanceUtils.setTint(adornee: Instance, color: Color3)
	local property = identifyTintProperty(adornee)
	assert(property, "Bad tintable")

	adornee[property] = color
end

--[=[
	Attempt to get an adornee's tint. Will return `nil` if no tint can be derived.

	@param adornee Instance
	@return Color3?
]=]
function TintableInstanceUtils.getTint(adornee: Instance): Color3?
	local property = identifyTintProperty(adornee)
	if property then
		return adornee[property]
	end
end

return TintableInstanceUtils
