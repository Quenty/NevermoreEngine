--[=[
	Utility involving the [Hide] binder.
	@class HideUtils
]=]

local CollectionService = game:GetService("CollectionService")
local HideUtils = {}

--[=[
	Returns whether the object in question is hidden. Prevents a requirement of binders
	being used, thus requiring a service bag.

	@param inst Instance
	@return boolean
]=]
function HideUtils.isHidden(inst: Instance): boolean
	return CollectionService:HasTag(inst, "Hide")
end

return HideUtils