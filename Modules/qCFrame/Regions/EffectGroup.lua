local EffectGroup = {}
EffectGroup.__index = EffectGroup
EffectGroup.ClassName = "EffectGroup"

-- @author Quenty

function EffectGroup.new()
	local self = {}
	setmetatable(self, EffectGroup)

	self.Fences = {}

	return self
end

function EffectGroup:AddEffectFence(Fence)
	-- @param Fence An EffectFence to add to the EffectGroup
	assert(Fence, "Must send Fence")

	self.Fences[Fence] = true
end

function EffectGroup:RemoveFence(Fence)
	-- @param Fence An already existing fence to remove
	assert(Fence, "Must send Fence")
	assert(self.Fences[Fence], "Fence must already be added to the group")

	self.Fences[Fence] = nil
end

function EffectGroup:FindFirstActive(Point)
	-- @return The fence that was used to cast.

	assert(Point, "Need point to cast")

	for Fence, _ in pairs(self.Fences) do
		if Fence:PointInFence(Point) then
			return Fence
		end
	end

	return nil
end

return EffectGroup