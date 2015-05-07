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

	self.Fences[#self.Fences+1] = Fence or error("No fence")
end

function EffectGroup:FindFirstActive(Point)
	-- @return The fence that was used to cast.

	assert(Point, "Need point to cast")

	for _, Fence in pairs(self.Fences) do
		if Fence:PointInFence(Point) then
			return Fence
		end
	end

	return nil
end

return EffectGroup