--!strict
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

function HideUtils.hasLocalTransparencyModifier(instance: Instance): boolean
	return instance:IsA("BasePart")
		or instance:IsA("Beam")
		or instance:IsA("Decal")
		or instance:IsA("Explosion")
		or instance:IsA("Fire")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("Trail")
end

function HideUtils.hasTransparency(instance: Instance): boolean
	return instance:IsA("BasePart")
		or instance:IsA("Beam")
		or instance:IsA("CanvasGroup")
		or instance:IsA("Decal")
		or instance:IsA("GuiBase3d")
		or instance:IsA("GuiObject")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Path2D")
		or instance:IsA("Terrain")
		or instance:IsA("Trail")
		or instance:IsA("UIGradient")
		or instance:IsA("UIStroke")
end

return HideUtils
